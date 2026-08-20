import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/favorites_repository.dart';

/// The caller's shortlist.
///
/// `autoDispose` so leaving the tab drops the list rather than holding a page
/// of decoded photos alive for the rest of the session.
final favoritesProvider =
    AsyncNotifierProvider.autoDispose<FavoritesController, FavoritesPage>(
      FavoritesController.new,
    );

class FavoritesController extends AutoDisposeAsyncNotifier<FavoritesPage> {
  @override
  Future<FavoritesPage> build() =>
      ref.watch(favoritesRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncValue<FavoritesPage>.loading();
    state = await AsyncValue.guard(
      () => ref.read(favoritesRepositoryProvider).list(),
    );
  }

  /// Loads the next page and appends it.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    try {
      final next = await ref
          .read(favoritesRepositoryProvider)
          .list(page: current.page + 1);
      state = AsyncValue<FavoritesPage>.data(
        FavoritesPage(
          profiles: <ProfileSummary>[...current.profiles, ...next.profiles],
          savedAt: <String, DateTime>{...current.savedAt, ...next.savedAt},
          page: next.page,
          totalPages: next.totalPages,
          total: next.total,
        ),
      );
    } on ApiException {
      // A failed page-two is not a reason to discard page one. The member keeps
      // what they have and can pull to retry.
    }
  }
}

/// Whether a given profile is on the caller's shortlist, and the toggle.
///
/// Kept separate from [favoritesProvider] so a heart on a discovery card does
/// not have to load the whole shortlist to know its own state. The set is
/// seeded from whatever pages have been fetched; a profile not yet seen reads
/// as not-saved, which is the safe direction — the API upserts, so saving an
/// already-saved profile is harmless.
final savedIdsProvider =
    NotifierProvider<SavedIdsController, Set<String>>(SavedIdsController.new);

class SavedIdsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool contains(String userId) => state.contains(userId);

  /// Records ids known to be saved, from a fetched shortlist page.
  void seed(Iterable<String> ids) {
    state = <String>{...state, ...ids};
  }

  /// Toggles, optimistically, and rolls back if the write fails.
  ///
  /// Optimistic because a heart that waits for a round trip before filling in
  /// feels broken; rolled back because silently showing a save that did not
  /// happen is worse than a brief flicker.
  Future<void> toggle(String userId) async {
    final wasSaved = state.contains(userId);
    state = wasSaved
        ? (<String>{...state}..remove(userId))
        : <String>{...state, userId};

    try {
      final repository = ref.read(favoritesRepositoryProvider);
      if (wasSaved) {
        await repository.remove(userId);
      } else {
        await repository.add(userId);
      }
      ref.invalidate(favoritesProvider);
    } on ApiException {
      state = wasSaved
          ? <String>{...state, userId}
          : (<String>{...state}..remove(userId));
      rethrow;
    }
  }
}
