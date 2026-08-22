import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/profile.dart';
import '../../data/models/settings.dart';
import '../../data/repositories/discovery_repository.dart';

/// The filters currently applied to the browse grid. Held above the screen so
/// they survive a tab switch.
final discoveryFiltersProvider = StateProvider<DiscoveryFilters>(
  (ref) => DiscoveryFilters.none,
);

/// A paginated list with its own loading and error state.
///
/// Written by hand rather than as a `FutureProvider` because infinite scroll
/// needs three things a future cannot express: appending to an existing page,
/// distinguishing "first load" from "loading more", and keeping the current
/// results visible while a later page fails.
@immutable
class PagedProfiles {
  const PagedProfiles({
    this.page = ProfilePage.empty,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final ProfilePage page;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;

  bool get isEmpty => page.profiles.isEmpty && !isLoading && error == null;
  bool get hasError => error != null && page.profiles.isEmpty;

  PagedProfiles copyWith({
    ProfilePage? page,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
  }) => PagedProfiles(
    page: page ?? this.page,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
  );
}

class BrowseNotifier extends StateNotifier<PagedProfiles> {
  BrowseNotifier(this._ref) : super(const PagedProfiles()) {
    load();
  }

  final Ref _ref;

  DiscoveryFilters get _filters => _ref.read(discoveryFiltersProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _ref
          .read(discoveryRepositoryProvider)
          .browse(filters: _filters, page: 1);
      if (!mounted) return;
      state = PagedProfiles(page: page);
    } on ApiException catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.page.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final next = await _ref
          .read(discoveryRepositoryProvider)
          .browse(filters: _filters, page: state.page.page + 1);
      if (!mounted) return;
      state = PagedProfiles(page: state.page.merge(next));
    } on ApiException catch (error) {
      if (!mounted) return;
      // Keep what is already on screen; only the "load more" attempt failed.
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  Future<void> refresh() => load();
}

final browseProvider = StateNotifierProvider<BrowseNotifier, PagedProfiles>((
  ref,
) {
  final notifier = BrowseNotifier(ref);
  // Changing a filter restarts from page 1 — appending across different filters
  // would interleave two different result sets.
  ref.listen<DiscoveryFilters>(discoveryFiltersProvider, (_, _) {
    notifier.load();
  });
  return notifier;
});

/// The home rail: members with an approved photo, scoped server-side.
///
/// Named for the endpoint (`/api/ladies`), not for who it returns. Since
/// 2026-08-21 that route filters on `resolveVisibleGenders()` like every other
/// listing, so a signed-in member whose preference includes men sees men here.
final ladiesProvider = FutureProvider.autoDispose<ProfilePage>((ref) async {
  return ref.watch(discoveryRepositoryProvider).ladies(limit: 12);
});

final spotlightProvider = FutureProvider.autoDispose<Spotlight>((ref) async {
  return ref.watch(discoveryRepositoryProvider).spotlight();
});

/// Whether the Live screen is showing only the five-minute window.
///
/// Defaults to false, matching the website: on a platform this young a strict
/// filter renders an empty page most of the time, and every member carries
/// their real [Presence] bucket anyway, so nothing is labelled "online" that
/// is not.
final liveStrictProvider = StateProvider<bool>((ref) => false);

/// Members who are online, or were recently — the app's equivalent of the
/// website's `/live`.
final liveProvider = FutureProvider.autoDispose<ProfilePage>((ref) async {
  final strict = ref.watch(liveStrictProvider);
  return ref
      .watch(discoveryRepositoryProvider)
      .online(strictlyOnline: strict, limit: 24);
});

final locationsProvider = FutureProvider.autoDispose<List<LocationCount>>((
  ref,
) async {
  return ref.watch(discoveryRepositoryProvider).locations();
});

/// A single public profile.
final profileByUsernameProvider = FutureProvider.autoDispose
    .family<ProfileSummary?, String>((ref, username) {
      return ref.watch(profileRepositoryProvider).publicProfile(username);
    });
