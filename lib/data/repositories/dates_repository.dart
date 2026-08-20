import '../../core/network/api_client.dart';
import '../models/json.dart';

/// Where a date proposal stands.
enum DateProposalStatus {
  pending('PENDING', 'Waiting for a reply'),
  accepted('ACCEPTED', 'Accepted'),
  declined('DECLINED', 'Declined'),
  rescheduled('RESCHEDULED', 'Rescheduled'),
  cancelled('CANCELLED', 'Cancelled');

  const DateProposalStatus(this.wire, this.label);

  final String wire;
  final String label;

  static DateProposalStatus parse(Object? value) {
    final raw = value?.toString().toUpperCase();
    for (final status in DateProposalStatus.values) {
      if (status.wire == raw) return status;
    }
    return DateProposalStatus.pending;
  }

  bool get isOpen => this == DateProposalStatus.pending;
}

/// A proposed meeting inside a match.
class DateProposal {
  const DateProposal({
    required this.id,
    required this.matchId,
    required this.proposedByUserId,
    required this.status,
    this.proposedTime,
    this.locationName,
    this.locationNote,
    this.createdAt,
  });

  final String id;
  final String matchId;
  final String proposedByUserId;
  final DateProposalStatus status;
  final DateTime? proposedTime;
  final String? locationName;
  final String? locationNote;
  final DateTime? createdAt;

  /// Whether [viewerId] may accept or decline. Only the *recipient* can — the
  /// backend rejects a proposer trying to accept their own proposal, and a
  /// button that produced a 400 would be a UI bug rather than a rule.
  bool canRespond(String? viewerId) =>
      status.isOpen && viewerId != null && viewerId != proposedByUserId;

  /// Whether [viewerId] may cancel. The mirror image: only the proposer.
  bool canCancel(String? viewerId) =>
      status.isOpen && viewerId != null && viewerId == proposedByUserId;

  factory DateProposal.fromJson(Map<String, dynamic> json) {
    return DateProposal(
      id: asString(json['id']),
      matchId: asString(json['matchId']),
      proposedByUserId: asString(json['proposedByUserId']),
      status: DateProposalStatus.parse(json['status']),
      proposedTime: asDateOrNull(json['proposedTime']),
      locationName: asStringOrNull(json['locationName']),
      locationNote: asStringOrNull(json['locationNote']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }
}

/// Date proposals inside a match.
///
/// **This arranges a meeting; it does not vouch for one.** The platform has no
/// booking, no payment and no verification of where anyone actually goes. The
/// proposal is a message with structure, and the safety guidance the app shows
/// elsewhere applies exactly as it does to any other arrangement made here.
///
/// Both endpoints refuse a match that has been unmatched, so a stale screen
/// answers 400 rather than quietly creating a proposal nobody can see.
class DatesRepository {
  DatesRepository(this._api);

  final ApiClient _api;

  /// Proposes a date. [proposedTime] is sent as UTC ISO-8601, which is what
  /// `z.string().datetime()` accepts — a local-offset string is rejected.
  Future<DateProposal> propose({
    required String matchId,
    required DateTime proposedTime,
    required String locationName,
    String? locationNote,
  }) async {
    final json = await _api.postJson(
      '/api/dates',
      body: <String, dynamic>{
        'matchId': matchId,
        'proposedTime': proposedTime.toUtc().toIso8601String(),
        'locationName': locationName.trim(),
        if (locationNote != null && locationNote.trim().isNotEmpty)
          'locationNote': locationNote.trim(),
      },
    );
    return DateProposal.fromJson(asMap(json['proposal']));
  }

  /// Accepts or declines. Only the recipient may call this.
  Future<DateProposal> respond({
    required String proposalId,
    required DateProposalStatus status,
  }) => _patch(proposalId, <String, dynamic>{'status': status.wire});

  /// Counters with a new time or place. Also recipient-only.
  Future<DateProposal> reschedule({
    required String proposalId,
    required DateTime proposedTime,
    String? locationName,
    String? locationNote,
  }) => _patch(proposalId, <String, dynamic>{
    'status': DateProposalStatus.rescheduled.wire,
    'proposedTime': proposedTime.toUtc().toIso8601String(),
    if (locationName != null && locationName.trim().isNotEmpty)
      'locationName': locationName.trim(),
    if (locationNote != null && locationNote.trim().isNotEmpty)
      'locationNote': locationNote.trim(),
  });

  /// Withdraws a proposal. Only the proposer may call this.
  Future<DateProposal> cancel(String proposalId) => _patch(
    proposalId,
    <String, dynamic>{'status': DateProposalStatus.cancelled.wire},
  );

  Future<DateProposal> _patch(String id, Map<String, dynamic> body) async {
    final json = await _api.patchJson('/api/dates/$id', body: body);
    return DateProposal.fromJson(asMap(json['proposal']));
  }
}
