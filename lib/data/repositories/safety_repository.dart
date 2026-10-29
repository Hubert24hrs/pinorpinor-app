import '../../core/constants/abuse_reasons.dart';
import '../../core/network/api_client.dart';

/// Bounds the website's own report form enforces, from `src/lib/support.ts`.
///
/// The minimum is not padding: `/api/report` accepts a one-character detail,
/// and the website refuses anything under ten with "it is what a moderator
/// acts on". Letting the app post a shorter one would file reports the site
/// would have rejected.
const int kReportDetailsMin = 10;

/// `/api/report` caps `details` at 4000. The app used to clamp to 1000 and
/// truncate silently mid-sentence, which cut the end off exactly the long,
/// careful accounts a moderator most needs.
const int kReportDetailsMax = 4000;

/// Reporting, blocking and unblocking.
///
/// Every decision here is enforced server-side: a block unmatches any existing
/// match in the same transaction, and both directions of a block are excluded
/// from discovery, swipes and contact requests. Nothing about that depends on
/// the app hiding a row.
class SafetyRepository {
  SafetyRepository(this._api);

  final ApiClient _api;

  /// Files an abuse report.
  ///
  /// Exactly one of [reportedUserId] and [reportedUsername] identifies the
  /// account: the id when the report comes from a profile the app has loaded,
  /// the username when a member typed it into the standalone Report Abuse
  /// screen. The route accepts either and resolves the username itself.
  ///
  /// [reasonId] is an id from [kAbuseReasons] -- never a label. The route runs
  /// `sanitizeAbuseReason`, so an unrecognised string is not rejected, it is
  /// quietly filed as `other` and the member's actual reason is lost.
  Future<void> report({
    required String reasonId,
    String? reportedUserId,
    String? reportedUsername,
    String? details,
  }) async {
    assert(
      (reportedUserId == null) != (reportedUsername == null),
      'report() needs exactly one of reportedUserId or reportedUsername',
    );
    assert(
      abuseReasonById(reasonId) != null,
      'reasonId must be an id from kAbuseReasons, not a label: got "$reasonId"',
    );

    final String? trimmed = details?.trim();
    await _api.postJson(
      '/api/report',
      body: <String, dynamic>{
        'reportedUserId': ?reportedUserId,
        'reportedUsername': ?reportedUsername,
        'reason': reasonId,
        if (trimmed != null && trimmed.isNotEmpty)
          'details': trimmed.length > kReportDetailsMax
              ? trimmed.substring(0, kReportDetailsMax)
              : trimmed,
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
