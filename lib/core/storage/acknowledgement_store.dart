import 'package:shared_preferences/shared_preferences.dart';

/// Records that the member confirmed they are 18 or over and accepted the
/// adult-content notice.
///
/// **Deliberately `SharedPreferences`, not secure storage.** This is a
/// disclosure record, not a credential. Nothing is protected by it — every
/// route that matters is gated server-side by `requireAuth()`, and the public
/// browse endpoints are open by design. Putting it in the Keychain would imply
/// a security property it does not have, and would survive an app reinstall,
/// which is the wrong behaviour for a notice the stores expect to be shown to
/// each new install.
///
/// It expires. An acknowledgement from a year ago on a shared or resold device
/// says nothing about who is holding it now, so re-asking periodically is both
/// more honest and what reviewers expect to see.
class AcknowledgementStore {
  AcknowledgementStore({SharedPreferences? preferences})
    : _injected = preferences;

  final SharedPreferences? _injected;

  static const _key = 'pnp.adult.acknowledged.at';

  /// How long an acknowledgement lasts before it is asked again.
  static const Duration ttl = Duration(days: 90);

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  /// True when a current, unexpired acknowledgement exists.
  ///
  /// Any failure reads as "not acknowledged". Showing the gate a second time is
  /// a mild annoyance; skipping it because storage misbehaved is the failure
  /// that matters.
  Future<bool> isAcknowledged({DateTime? now}) async {
    try {
      final prefs = await _prefs;
      final millis = prefs.getInt(_key);
      if (millis == null) return false;

      final acknowledgedAt = DateTime.fromMillisecondsSinceEpoch(millis);
      final elapsed = (now ?? DateTime.now()).difference(acknowledgedAt);

      // A negative elapsed means the device clock moved backwards since the
      // acknowledgement. Treat that as expired rather than trusting it.
      if (elapsed.isNegative) return false;
      return elapsed < ttl;
    } on Exception {
      return false;
    }
  }

  Future<void> acknowledge({DateTime? now}) async {
    try {
      final prefs = await _prefs;
      await prefs.setInt(_key, (now ?? DateTime.now()).millisecondsSinceEpoch);
    } on Exception {
      // Storage unavailable. The member is asked again next launch, which is
      // the safe direction to fail.
    }
  }

  /// Clears the record. Used by the "not 18" path so the gate reappears
  /// immediately rather than after a restart.
  Future<void> clear() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_key);
    } on Exception {
      // Nothing to do — an un-clearable record still expires on its own.
    }
  }
}
