import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/utils/age.dart';

/// The age bound, which registration had none of for eight days.
///
/// Date of birth was dropped on 2026-08-14, and until `birthYear` arrived on
/// 2026-08-21 the 18+ tickbox was the only thing between a minor and an account.
/// This is what restored a server-side check, and the app mirrors it so a member
/// is told before a round trip — with the backend's own wording, so nobody sees
/// two different explanations for one refusal.
///
/// **It is a declaration with a sanity bound, not verification.** Nothing here
/// proves anything, the measure is approximate by up to a year, and no copy in
/// the product may describe it as verified.
void main() {
  // Fixed, so the assertions do not drift with the calendar.
  final DateTime now = DateTime.utc(2026, 8, 25);

  group('resolving an age', () {
    test('null when nothing is known, and that is a real answer', () {
      // Rendering "unknown" or guessing would put a claim on a real person's
      // public profile that they never made.
      expect(resolveAge(now: now), isNull);
      expect(resolveAge(birthYear: null, birthDate: null, now: now), isNull);
    });

    test('an exact date beats a derived year', () {
      final int? age = resolveAge(
        birthDate: DateTime.utc(2000, 12, 31),
        birthYear: 1990,
        now: now,
      );
      expect(age, 25, reason: 'the date is exact and wins');
    });

    test('a date before the birthday this year has not counted it yet', () {
      expect(resolveAge(birthDate: DateTime.utc(2000, 12, 31), now: now), 25);
      expect(resolveAge(birthDate: DateTime.utc(2000, 1, 1), now: now), 26);
    });

    test('a year alone gives the age they turn this year', () {
      // Deliberate and documented imprecision: for most of the calendar this
      // reads a year high, which is the trade against three fields most people
      // abandon.
      expect(resolveAge(birthYear: 2000, now: now), 26);
    });

    test('nonsense is null rather than a negative or a 900-year-old', () {
      expect(resolveAge(birthYear: 2100, now: now), isNull);
      expect(resolveAge(birthYear: 1800, now: now), isNull);
    });
  });

  group('validating a typed year', () {
    test('accepts a plain adult year', () {
      final BirthYearCheck check = validateBirthYear('1998', now);
      expect(check, isA<BirthYearValid>());
      expect((check as BirthYearValid).year, 1998);
    });

    test('accepts a number as well as a string, because forms send both', () {
      expect(validateBirthYear(1998, now), isA<BirthYearValid>());
    });

    test('refuses anything that is not a year', () {
      expect(birthYearError('', now), contains('year of birth'));
      expect(birthYearError('nineteen', now), contains('year of birth'));
      expect(birthYearError(null, now), isNotNull);
    });

    test('refuses a year below the database floor', () {
      expect(
        birthYearError('1899', now),
        'That year of birth does not look right.',
      );
      expect(birthYearError('$kMinBirthYear', now), isNull);
    });

    test('refuses a year that makes them under 18', () {
      expect(birthYearError('2010', now), contains('18 or over'));
      expect(birthYearError('2009', now), contains('18 or over'));
    });

    test('the boundary is the year they turn 18, in the member\'s favour', () {
      // Somebody born in 2008 is accepted throughout 2026 even if they do not
      // turn 18 until December. That is the approximation, stated rather than
      // hidden, and it is the same one the route makes.
      expect(maxAdultBirthYear(now), 2008);
      expect(
        birthYearError('2008', now),
        isNull,
        reason: 'they turn 18 at some point in 2026, so they are accepted now',
      );
      expect(birthYearError('2009', now), isNotNull);
    });
  });
}
