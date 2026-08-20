import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/data/models/presence.dart';
import 'package:pinorpinor_app/data/models/profile.dart';

/// Presence is deliberately coarse, and the app must not make it finer.
///
/// The website's `src/lib/presence.ts` exposes four wide buckets and never the
/// underlying `users.lastSeenAt`, because a precise last-active time published
/// to strangers is a movement log — watched over a few days it shows when
/// someone sleeps, works and is alone at home.
///
/// These tests pin the two properties that matter: unknown input degrades to
/// the *least* revealing answer, and only the five-minute bucket claims a
/// member is present.
void main() {
  group('parsing', () {
    test('reads the four documented buckets', () {
      expect(Presence.parse('ONLINE'), Presence.online);
      expect(Presence.parse('TODAY'), Presence.today);
      expect(Presence.parse('THIS_WEEK'), Presence.thisWeek);
      expect(Presence.parse('AWAY'), Presence.away);
    });

    test('is case-insensitive', () {
      expect(Presence.parse('online'), Presence.online);
    });

    test('anything unrecognised falls back to away', () {
      // The safe direction: an unknown value must never be read as a claim
      // that someone is present.
      expect(Presence.parse(null), Presence.away);
      expect(Presence.parse(''), Presence.away);
      expect(Presence.parse('LIVE'), Presence.away);
      expect(Presence.parse(42), Presence.away);
    });
  });

  group('the online indicator', () {
    test('only ONLINE counts as present', () {
      expect(Presence.online.isOnlineNow, isTrue);
      // A dot for "active this week" would make an absent member look present.
      expect(Presence.today.isOnlineNow, isFalse);
      expect(Presence.thisWeek.isOnlineNow, isFalse);
      expect(Presence.away.isOnlineNow, isFalse);
    });

    test('every bucket has readable copy', () {
      for (final presence in Presence.values) {
        expect(presence.label.trim(), isNotEmpty);
      }
    });
  });

  group('on a profile', () {
    test('presence is read from the user, not the dating profile', () {
      // It is a bucket of `users.lastSeenAt`, so it is serialised beside the
      // username rather than inside `datingProfile`.
      final profile = ProfileSummary.fromJson(<String, dynamic>{
        'id': 'u1',
        'username': 'zainab',
        'presence': 'ONLINE',
        'datingProfile': <String, dynamic>{'city': 'Lagos'},
      });

      expect(profile.presence, Presence.online);
    });

    test('a response without presence reads as away', () {
      final profile = ProfileSummary.fromJson(<String, dynamic>{
        'id': 'u1',
        'username': 'zainab',
      });

      expect(profile.presence, Presence.away);
      expect(profile.presence.isOnlineNow, isFalse);
    });
  });
}
