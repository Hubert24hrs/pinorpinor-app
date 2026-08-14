import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/messaging.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/discovery_repository.dart';
import 'discovery_providers.dart';

/// The swipe deck's state.
///
/// The deck is a queue, not an index into a list. Cards are removed as they are
/// acted on, so the widget tree only ever holds the top two — the visible card
/// and the one peeking behind it. Indexing into a growing list instead (as the
/// reference project does) keeps every consumed profile alive in memory and
/// makes "undo" and rollback awkward.
@immutable
class SwipeDeckState {
  const SwipeDeckState({
    this.queue = const <ProfileSummary>[],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.exhausted = false,
    this.error,
    this.actionError,
    this.lastMatch,
  });

  /// Cards still to act on. `first` is the top card.
  final List<ProfileSummary> queue;

  final bool isLoading;
  final bool isLoadingMore;

  /// The server has no more candidates. Distinct from an empty queue during
  /// loading, which is why it is a separate flag.
  final bool exhausted;

  /// Fatal — nothing to show.
  final Object? error;

  /// A swipe failed. The card came back; this explains why.
  final String? actionError;

  /// Set when a swipe produced a mutual like, so the UI can celebrate and offer
  /// the conversation. Cleared once shown.
  final SwipeResult? lastMatch;

  ProfileSummary? get top => queue.isEmpty ? null : queue.first;
  ProfileSummary? get next => queue.length < 2 ? null : queue[1];

  bool get isEmpty => queue.isEmpty && !isLoading && error == null;

  SwipeDeckState copyWith({
    List<ProfileSummary>? queue,
    bool? isLoading,
    bool? isLoadingMore,
    bool? exhausted,
    Object? error,
    String? actionError,
    SwipeResult? lastMatch,
    bool clearError = false,
    bool clearActionError = false,
    bool clearMatch = false,
  }) => SwipeDeckState(
    queue: queue ?? this.queue,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    exhausted: exhausted ?? this.exhausted,
    error: clearError ? null : (error ?? this.error),
    actionError: clearActionError ? null : (actionError ?? this.actionError),
    lastMatch: clearMatch ? null : (lastMatch ?? this.lastMatch),
  );
}

/// Drives the swipe deck against `/api/discover` and `/api/swipe`.
///
/// **Optimistic, with rollback.** The card leaves immediately — waiting for a
/// round trip before the next profile appears makes the deck feel broken on a
/// mobile connection. If the POST then fails, the card is put back at the front
/// and the reason surfaced. That matters more here than in most optimistic UI:
/// a swipe is a *recorded decision*. Dropping a failed one silently would mean
/// the member never sees that profile again, because the server excludes
/// already-swiped ids — except it was never recorded, so they would see it
/// again anyway, having believed they had passed.
class SwipeDeckController extends StateNotifier<SwipeDeckState> {
  SwipeDeckController(this._ref) : super(const SwipeDeckState()) {
    load();
  }

  final Ref _ref;

  /// Server page cursor. `/api/discover` excludes already-swiped ids, so the
  /// same page number returns fresh candidates after a batch of swipes — but
  /// paging forward is still needed while a page is only partly consumed.
  int _page = 1;

  /// Fetch more when the queue gets this short, so the member never waits.
  static const _prefetchThreshold = 3;

  DiscoveryFilters get _filters => _ref.read(discoveryFiltersProvider);

  Future<void> load() async {
    state = const SwipeDeckState();
    _page = 1;
    try {
      final candidates = await _ref
          .read(discoveryRepositoryProvider)
          .deck(filters: _filters);
      if (!mounted) return;
      state = SwipeDeckState(
        queue: candidates,
        isLoading: false,
        exhausted: candidates.isEmpty,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> _prefetch() async {
    if (state.isLoadingMore || state.exhausted) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final more = await _ref
          .read(discoveryRepositoryProvider)
          .deck(filters: _filters, page: _page + 1);
      if (!mounted) return;

      if (more.isEmpty) {
        // Nothing further. Not an error — the member has seen everyone in
        // their country matching their preference.
        state = state.copyWith(isLoadingMore: false, exhausted: true);
        return;
      }

      _page++;
      // Guard against the server returning something already queued: the
      // exclusion list is built per request, so a swipe in flight during the
      // fetch can produce an overlap.
      final known = state.queue.map((p) => p.id).toSet();
      state = state.copyWith(
        queue: <ProfileSummary>[
          ...state.queue,
          ...more.where((p) => !known.contains(p.id)),
        ],
        isLoadingMore: false,
      );
    } on ApiException {
      // Silent: the member still has cards. The next swipe retries.
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> like() => _act(SwipeActionInput.like);
  Future<void> pass() => _act(SwipeActionInput.pass);
  Future<void> superlike() => _act(SwipeActionInput.superlike);

  Future<void> _act(SwipeActionInput action) async {
    final card = state.top;
    if (card == null) return;

    // Off the deck immediately.
    final remaining = state.queue.skip(1).toList(growable: false);
    state = state.copyWith(queue: remaining, clearActionError: true);

    if (remaining.length <= _prefetchThreshold) {
      unawaited(_prefetch());
    }

    try {
      final result = await _ref
          .read(discoveryRepositoryProvider)
          .swipe(targetUserId: card.id, action: action);
      if (!mounted) return;

      if (result.matched) {
        state = state.copyWith(lastMatch: result);
      }
      if (state.queue.isEmpty && !state.isLoadingMore) {
        state = state.copyWith(exhausted: true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;

      // A 403/404 means the server refused this pairing — blocked, or the
      // account is gone. Putting the card back would show it again and fail
      // again, so it stays gone; only the reason surfaces.
      final permanent =
          error.kind == ApiErrorKind.forbidden ||
          error.kind == ApiErrorKind.notFound;

      state = state.copyWith(
        queue: permanent ? state.queue : <ProfileSummary>[card, ...state.queue],
        actionError: error.message,
      );
    }
  }

  /// Dismisses the match celebration.
  void clearMatch() => state = state.copyWith(clearMatch: true);

  void clearActionError() => state = state.copyWith(clearActionError: true);

  Future<void> refresh() => load();
}

final swipeDeckProvider =
    StateNotifierProvider.autoDispose<SwipeDeckController, SwipeDeckState>((
      ref,
    ) {
      final controller = SwipeDeckController(ref);
      // Changing a filter rebuilds the deck — the server applies filters when
      // it builds the candidate list, so the queue in hand is stale.
      ref.listen<DiscoveryFilters>(discoveryFiltersProvider, (_, _) {
        controller.load();
      });
      return controller;
    });
