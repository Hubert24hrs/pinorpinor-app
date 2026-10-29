/// The abuse-report reasons, mirrored from the website's `src/lib/support.ts`.
///
/// **The id is what goes on the wire, not the label.** `/api/report` passes
/// whatever it receives through `sanitizeAbuseReason`, which accepts only the
/// seven ids below and rewrites everything else to `other`. The app used to
/// send its own labels as free text — a decision that was correct when the
/// route stored the string as given, and silently wrong from the day the
/// sanitiser landed.
///
/// The cost was invisible from here: the request succeeded, the member saw
/// "thank you", and the moderator queue showed **Something else** for every
/// report the app had ever sent. A member reporting a profile as underage
/// reached a moderator with the one fact that mattered removed.
///
/// `test/unit/abuse_reasons_test.dart` reads the real TypeScript and fails if
/// an id here stops existing there, which is the only thing that keeps the two
/// lists honest.
library;

import 'package:flutter/foundation.dart';

@immutable
class AbuseReason {
  const AbuseReason({required this.id, required this.label});

  /// The value `/api/report` stores. Must exist in `ABUSE_REASONS`.
  final String id;

  /// What the member reads. Mirrors the website's wording so a member who has
  /// reported on the site recognises the option here.
  final String label;
}

/// In the website's order, which is roughly most-urgent first.
const List<AbuseReason> kAbuseReasons = <AbuseReason>[
  AbuseReason(id: 'harassment', label: 'Harassment or threats'),
  AbuseReason(id: 'fake_profile', label: 'Fake profile or impersonation'),
  AbuseReason(id: 'stolen_media', label: 'Stolen or non-consensual photos'),
  AbuseReason(id: 'underage', label: 'I believe this person is under 18'),
  AbuseReason(id: 'scam', label: 'Scam or attempted fraud'),
  AbuseReason(id: 'non_consent', label: 'Behaviour that was not consented to'),
  AbuseReason(id: 'other', label: 'Something else'),
];

/// What the server falls back to, and what the app preselects nowhere: the
/// picker starts empty so a member chooses rather than accepting a default
/// that says nothing.
const String kDefaultAbuseReason = 'other';

AbuseReason? abuseReasonById(String id) {
  for (final reason in kAbuseReasons) {
    if (reason.id == id) return reason;
  }
  return null;
}
