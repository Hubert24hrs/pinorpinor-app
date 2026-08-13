import '../../core/network/api_client.dart';

/// The reasons offered when reporting. Sent as free text — the backend accepts
/// any string up to 100 characters — but a fixed list keeps moderation triage
/// consistent between the app and the website.
enum ReportReason {
  fakeProfile('Fake or impersonated profile'),
  inappropriateMedia('Inappropriate photos or video'),
  harassment('Harassment or abusive messages'),
  spamOrScam('Spam, scam or solicitation'),
  underage('This person appears to be under 18'),
  offPlatform('Pressured me off the platform'),
  other('Something else');

  const ReportReason(this.label);
  final String label;

  /// The stored value. The label doubles as the reason so a moderator reading
  /// the queue sees the member's own words rather than an internal code.
  String get wire => label;
}

/// Reporting, blocking and unblocking.
///
/// Every decision here is enforced server-side: a block unmatches any existing
/// match in the same transaction, and both directions of a block are excluded
/// from discovery, swipes and contact requests. Nothing about that depends on
/// the app hiding a row.
class SafetyRepository {
  SafetyRepository(this._api);

  final ApiClient _api;

  Future<void> report({
    required String reportedUserId,
    required ReportReason reason,
    String? details,
  }) async {
    await _api.postJson(
      '/api/report',
      body: <String, dynamic>{
        'reportedUserId': reportedUserId,
        'reason': reason.wire,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim().substring(
            0,
            details.trim().length.clamp(0, 1000),
          ),
      },
    );
  }

  Future<void> block(String blockedUserId) async {
    await _api.postJson(
      '/api/block',
      body: <String, String>{'blockedUserId': blockedUserId},
    );
  }

  Future<void> unblock(String blockedUserId) async {
    await _api.deleteJson(
      '/api/block',
      query: <String, dynamic>{'blockedUserId': blockedUserId},
    );
  }
}
