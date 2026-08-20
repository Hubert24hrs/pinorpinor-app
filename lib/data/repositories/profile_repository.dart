import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/account.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/profile.dart';
import '../models/settings.dart';

/// Reads and writes to the member's own profile, and reads other members'.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// The caller's own profile, including media still awaiting moderation.
  Future<Account> myProfile() async =>
      Account.fromJson(await _api.getJson('/api/profile'));

  /// Updates the editable profile fields.
  ///
  /// The backend whitelists what it accepts (`profileUpdateSchema`), so a field
  /// this client does not know about cannot be smuggled through — including the
  /// boost and credit columns, which is what stops a member self-promoting.
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? tagline,
    String? height,
    String? ethnicity,
    String? city,
    String? country,
    RelationshipIntent? relationshipIntent,
    List<String>? dateTypes,
    bool? isAvailableToday,
  }) async {
    final body = <String, dynamic>{
      if (displayName != null) 'displayName': displayName.trim(),
      if (bio != null) 'bio': bio.trim(),
      if (tagline != null) 'tagline': tagline.trim(),
      if (height != null) 'height': height.trim(),
      if (ethnicity != null) 'ethnicity': ethnicity.trim(),
      if (city != null) 'city': city.trim(),
      'country': ?country,
      if (relationshipIntent != null)
        'relationshipIntent': relationshipIntent.wire,
      'dateTypes': ?dateTypes,
      'isAvailableToday': ?isAvailableToday,
    };
    if (body.isEmpty) return;
    await _api.patchJson('/api/profile', body: body);
  }

  /// A public profile by username.
  ///
  /// Returns null for 404, which the backend uses for every unavailable case —
  /// missing, hidden, suspended or male — so the app cannot tell them apart
  /// either. That is intentional: it stops username probing.
  Future<ProfileSummary?> publicProfile(String username) async {
    try {
      final json = await _api.getJson(
        '/api/public/profiles/${Uri.encodeComponent(username.trim().toLowerCase())}',
      );
      final profile = asMap(json['profile']);
      if (profile.isEmpty) return null;
      return ProfileSummary.fromJson(profile);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  /// `interestedIn` — who the member wants to see. Read from the database on
  /// every discovery query, never from the request, so changing it here is the
  /// only way to change what discovery returns.
  Future<InterestedIn> preferences() async {
    final json = await _api.getJson('/api/settings/preferences');
    return InterestedIn.parse(json['interestedIn']) ??
        InterestedIn.defaultFor(Gender.parse(json['gender']));
  }

  Future<InterestedIn> updatePreferences(InterestedIn value) async {
    final json = await _api.patchJson(
      '/api/settings/preferences',
      body: <String, String>{'interestedIn': value.wire},
    );
    return InterestedIn.parse(json['interestedIn']) ?? value;
  }

  Future<SettingsBundle> settings() async =>
      SettingsBundle.fromJson(await _api.getJson('/api/settings'));

  Future<MemberSettings> updateSettings(MemberSettings settings) async {
    final json = await _api.patchJson(
      '/api/settings',
      body: settings.toPatch(),
    );
    return MemberSettings.fromJson(json);
  }

  /// Deactivates the account — `DELETE /api/settings` sets `isActive: false`.
  ///
  /// From that moment `requireAuth()` answers 403 on every call and the profile
  /// disappears from every public surface, because each read path filters on
  /// `isActive`. **Reversible**, and the right choice for someone taking a
  /// break. For permanent erasure use [deleteAccount].
  Future<void> deactivateAccount() async {
    await _api.deleteJson('/api/settings');
  }

  /// **Permanently deletes the account.** `DELETE /api/account`.
  ///
  /// Distinct from [deactivateAccount] in every way that matters: this cannot
  /// be undone, and it removes the member's uploaded objects from the storage
  /// bucket *before* deleting the rows. That order is not incidental —
  /// `storageKey` lives only on the `media` rows, and deleting the user
  /// cascades those away, so doing it the other way round would strand every
  /// photograph in a private bucket with nothing left pointing at it.
  ///
  /// **The password is required and re-checked server-side.** Sessions are
  /// 30-day JWTs, so without it anyone holding an unlocked phone could destroy
  /// the account and all its media in two taps. A wrong password answers 403.
  ///
  /// Accounts with no password — which now includes nothing, but the column is
  /// nullable — are refused with a message pointing at support.
  Future<void> deleteAccount({required String password}) async {
    await _api.deleteJson(
      '/api/account',
      body: <String, String>{'password': password},
    );
  }
}
