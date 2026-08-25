import '../../core/network/api_client.dart';
import '../models/json.dart';

/// Contact Us — `POST /api/support`.
///
/// ## Sign-in is required, and it is a real trade
///
/// The identity comes from the session, never from the request: a form that
/// lets the sender type their own username is a form that lets anyone file
/// complaints as anyone else, and a moderator reading the queue has no way to
/// tell. The cost is that somebody who cannot sign in — the exact person most
/// likely to need support — cannot use it, which is why the app keeps the
/// website's Contact page reachable from the menu for everyone else.
class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  /// Files a support message. Returns the id an admin will work it by.
  Future<String> send({
    required String message,
    String category = kDefaultSupportCategory,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/api/support',
      body: <String, String>{
        'category': sanitizeSupportCategory(category),
        'message': message.trim(),
      },
    );
    return asString(json['id']);
  }
}

/// One reason a member might be writing in.
class SupportCategory {
  const SupportCategory(this.id, this.label);

  /// Stored value. Never change it once shipped.
  final String id;

  /// Display text.
  final String label;
}

/// Mirrors `SUPPORT_CATEGORIES`. An unrecognised id is coerced rather than
/// rejected, exactly as `sanitizeSupportCategory` does, so a stale screen still
/// gets its message through.
const List<SupportCategory> kSupportCategories = <SupportCategory>[
  SupportCategory('general', 'General enquiry'),
  SupportCategory('account', 'Account or sign-in problem'),
  SupportCategory('credits', 'Credits or a top-up'),
  SupportCategory('media_removal', 'Media removal request'),
  SupportCategory('profile', 'Profile or moderation question'),
  SupportCategory('other', 'Something else'),
];

const String kDefaultSupportCategory = 'general';

/// The bounds the route enforces, so a member is told before a round trip.
const int kSupportMessageMin = 10;
const int kSupportMessageMax = 4000;

String sanitizeSupportCategory(String? input) {
  for (final SupportCategory c in kSupportCategories) {
    if (c.id == input) return c.id;
  }
  return kDefaultSupportCategory;
}

/// The route's own wording for a message that is too short or too long.
String? supportMessageError(String? raw) {
  final String value = (raw ?? '').trim();
  if (value.length < kSupportMessageMin) {
    return 'Please write at least $kSupportMessageMin characters.';
  }
  if (value.length > kSupportMessageMax) {
    return 'Please keep it under $kSupportMessageMax characters.';
  }
  return null;
}
