import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/utils/validators.dart';

/// The sign-in and registration contracts, pinned at the field level.
///
/// **Why this file exists.** On 2026-08-14 the website renamed the credentials
/// field from `email` to `identifier` and rebuilt registration down to six
/// fields. The app kept sending the old shapes, and *nothing caught it*: the
/// analyzer was clean, every test passed, the APK built and installed. The only
/// symptom was a 401 on every sign-in attempt, which is indistinguishable from
/// a wrong password.
///
/// A widget test cannot catch this class of break either — the fake repository
/// has whatever signature the real one has. What follows guards the piece that
/// is checkable without a network: the validation rules that decide what the
/// app is willing to send.
void main() {
  group('login identifier', () {
    test('accepts a bare username, which is now the common case', () {
      // Registration stopped collecting an email, so most accounts have only a
      // username. Validating this field as an email would lock them all out.
      expect(Validators.loginIdentifier('zainab_lagos'), isNull);
      expect(Validators.loginIdentifier('abc'), isNull);
    });

    test('still accepts an email, for accounts that predate the change', () {
      expect(Validators.loginIdentifier('member@example.com'), isNull);
    });

    test('validates as an email only when an "@" is present', () {
      // That is exactly how the backend decides which column to search:
      //   const where = value.includes("@") ? { email: value } : { username: value }
      expect(Validators.loginIdentifier('not-an-email@'), isNotNull);
      // The same string without the "@" is a perfectly good username.
      expect(Validators.loginIdentifier('not-an-email'), isNull);
    });

    test('rejects an empty field', () {
      expect(Validators.loginIdentifier(''), isNotNull);
      expect(Validators.loginIdentifier('   '), isNotNull);
      expect(Validators.loginIdentifier(null), isNotNull);
    });

    test('is looser than the sign-up username rules, on purpose', () {
      // This is a lookup key for an account that already exists. Rejecting a
      // legacy name that predates the current rules would leave its owner
      // unable to sign in with a name the server still accepts.
      const legacy = 'Old.Name';
      expect(
        UsernameRules.validate(legacy),
        isNotNull,
        reason: 'the sign-up rules should reject this',
      );
      expect(
        Validators.loginIdentifier(legacy),
        isNull,
        reason: 'but sign-in must not',
      );
    });
  });

  group('registration rules the backend enforces', () {
    test('a WhatsApp number must be in international format', () {
      // normalizePhone: /^\+[1-9]\d{7,14}$/
      expect(Validators.phone('+2348012345678'), isNull);
      expect(
        Validators.phone('08012345678'),
        isNotNull,
        reason: 'no country code; the backend cannot resolve a country from '
            'this, and discovery scopes on country',
      );
      expect(Validators.phone('+0123456789'), isNotNull, reason: 'leading zero');
    });

    test('the password floor matches the route', () {
      // The username is now the only way back into an account, so the floor
      // matters more than it did, not less.
      expect(Validators.password('1234567'), isNotNull);
      expect(Validators.password('12345678'), isNull);
      expect(Validators.password('x' * 101), isNotNull);
    });
  });
}
