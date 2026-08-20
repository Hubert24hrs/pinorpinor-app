import '../../core/network/api_client.dart';
import '../models/json.dart';
import '../models/profile.dart';

/// A member's saved profiles.
///
/// **Private by construction, in both directions.** Only the owner can read or
/// change their own shortlist, and the saved member is never told — being able
/// to see who has quietly bookmarked you would turn the feature into a
/// surveillance signal on a platform where women are browsed by strangers. The
/// count is not published on the target's profile either, so there is no
/// popularity number here to render.
///
/// Nothing in this file should grow a "who saved me" call. The backend has no
/// such endpoint, deliberately.
class FavoritesRepository {
  FavoritesRepository(this._api);

  final ApiClient _api;

  /// The caller's own shortlist, newest first.
  ///
  /// Blocks in either direction are filtered server-side, so a card can
  /// disappear between pages — that is correct, not a paging bug.
  Future<FavoritesPage> list({int page = 1, int limit = 24}) async {
    final json = await _api.getJson(
      '/api/favorites',
      query: <String, dynamic>{'page': page, 'limit': limit},
    );
    return FavoritesPage.fromJson(json);
  }

  /// Saves a profile. Idempotent — the route upserts, so a double tap is a
  /// success rather than a conflict the UI has to special-case.
  Future<void> add(String targetUserId) async {
    await _api.postJson(
      '/api/favorites',
      body: <String, String>{'targetUserId': targetUserId},
    );
  }

  /// Removes a save. Also idempotent: deleting one that is not there succeeds.
  Future<void> remove(String targetUserId) async {
    await _api.deleteJson(
      '/api/favorites',
      query: <String, dynamic>{'targetUserId': targetUserId},
    );
  }
}

/// A page of saved profiles.
class FavoritesPage {
  const FavoritesPage({
    this.profiles = const <ProfileSummary>[],
    this.savedAt = const <String, DateTime>{},
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
  });

  static const FavoritesPage empty = FavoritesPage();

  final List<ProfileSummary> profiles;

  /// When each profile was saved, keyed by user id. Kept beside the profiles
  /// rather than on [ProfileSummary] because it is a fact about the *viewer's*
  /// shortlist, not about the member.
  final Map<String, DateTime> savedAt;

  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory FavoritesPage.fromJson(Map<String, dynamic> json) {
    final rows = asMapList(json['favorites']);
    final pagination = asMap(json['pagination']);

    final profiles = <ProfileSummary>[];
    final saved = <String, DateTime>{};
    for (final row in rows) {
      final profile = ProfileSummary.fromJson(row);
      profiles.add(profile);
      final at = asDateOrNull(row['savedAt']);
      if (at != null) saved[profile.id] = at;
    }

    return FavoritesPage(
      profiles: profiles,
      savedAt: saved,
      page: asIntOrNull(pagination['page']) ?? 1,
      totalPages: asIntOrNull(pagination['totalPages']) ?? 1,
      total: asIntOrNull(pagination['total']) ?? profiles.length,
    );
  }
}
