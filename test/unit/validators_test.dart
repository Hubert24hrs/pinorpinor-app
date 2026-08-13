import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/utils/validators.dart';

/// These mirror rules the backend also enforces. The point of testing them is
/// not that the client is authoritative — it is not — but that the two agree,
/// so a member never sees "looks fine" here and a rejection from the server.
void main() {
  group('UsernameRules', () {
    test('accepts a well-formed username', () {
      expect(UsernameRules.validate('zainab_lagos'), isNull);
      expect(UsernameRules.validate('abc'), isNull);
      expect(UsernameRules.validate('a1234567890123456789'), isNull);
    });

    test('folds to lowercase before validating', () {
      // The database CHECK forbids uppercase, which is what makes the plain
      // unique index case-insensitive. Normalising here keeps the two aligned.
      expect(UsernameRules.normalize('  ZaInAb  '), 'zainab');
      expect(UsernameRules.validate('ZAINAB'), isNull);
    });

    test('rejects the length boundaries', () {
      expect(UsernameRules.validate('ab'), contains('at least 3'));
      expect(
        UsernameRules.validate('a' * 21),
        contains('20 characters or fewer'),
      );
    });

    test('rejects illegal characters rather than stripping them', () {
      // Silently rewriting input would hand someone an account under a name
      // they did not choose.
      expect(UsernameRules.validate('zainab-lagos'), isNotNull);
      expect(UsernameRules.validate('zainab lagos'), isNotNull);
      expect(UsernameRules.validate('zaïnab'), isNotNull);
    });

    test('enforces the app-level shape rules', () {
      expect(
        UsernameRules.validate('1zainab'),
        contains('start with a letter'),
      );
      expect(UsernameRules.validate('zainab_'), contains('end with'));
      expect(UsernameRules.validate('zai__nab'), contains('two underscores'));
    });

    test('rejects reserved names', () {
      // Two hazards: a route-shadowing name makes the member's own profile
      // unreachable, and names like "admin" read as official accounts.
      for (final reserved in <String>['settings', 'admin', 'api', 'support']) {
        expect(
          UsernameRules.validate(reserved),
          contains('reserved'),
          reason: '$reserved must be rejected',
        );
      }
    });

    test('rejects empty input', () {
      expect(UsernameRules.validate(''), isNotNull);
      expect(UsernameRules.validate(null), isNotNull);
      expect(UsernameRules.validate('   '), isNotNull);
    });
  });

  group('Validators.email', () {
    test('accepts ordinary addresses', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('  User@Example.COM  '), isNull);
    });

    test('rejects malformed addresses', () {
      for (final bad in <String>[
        '',
        'user',
        'user@',
        '@example.com',
        'a@b.c',
      ]) {
        expect(Validators.email(bad), isNotNull, reason: '"$bad" must fail');
      }
    });
  });

  group('Validators.password', () {
    test('enforces the 8-character floor the backend requires', () {
      expect(Validators.password('1234567'), contains('at least 8'));
      expect(Validators.password('12345678'), isNull);
    });

    test('enforces the 100-character ceiling', () {
      expect(Validators.password('a' * 100), isNull);
      expect(Validators.password('a' * 101), isNotNull);
    });

    test('confirmation must match exactly', () {
      expect(Validators.confirmPassword('secret123', 'secret123'), isNull);
      expect(Validators.confirmPassword('secret123', 'Secret123'), isNotNull);
      expect(Validators.confirmPassword('', 'secret123'), isNotNull);
    });
  });

  group('Age gate', () {
    final now = DateTime(2026, 8, 13);

    test('computes age across a birthday boundary', () {
      expect(Validators.ageOn(DateTime(2008, 8, 13), now), 18);
      // One day before the eighteenth birthday.
      expect(Validators.ageOn(DateTime(2008, 8, 14), now), 17);
      expect(Validators.ageOn(DateTime(2008, 12, 31), now), 17);
      expect(Validators.ageOn(DateTime(2008, 1, 1), now), 18);
    });

    test('isAdult is exactly 18 and over', () {
      expect(Validators.isAdult(DateTime(2008, 8, 13), now), isTrue);
      expect(Validators.isAdult(DateTime(2008, 8, 14), now), isFalse);
    });

    test('rejects an underage date of birth with the platform wording', () {
      final message = Validators.birthDate(DateTime(2015, 1, 1));
      expect(message, isNotNull);
      expect(message, contains('at least 18'));
    });

    test('rejects a missing or future date', () {
      expect(Validators.birthDate(null), isNotNull);
      expect(
        Validators.birthDate(DateTime.now().add(const Duration(days: 1))),
        isNotNull,
      );
    });

    test('accepts an adult date of birth', () {
      expect(Validators.birthDate(DateTime(1995, 6, 15)), isNull);
    });
  });

  group('Validators.phone', () {
    test('accepts E.164', () {
      expect(Validators.phone('+2348012345678'), isNull);
      expect(Validators.phone('+44 7700 900123'), isNull);
    });

    test('rejects anything the backend would reject', () {
      for (final bad in <String>['08012345678', '+0801234', '2348012345678']) {
        expect(Validators.phone(bad), isNotNull, reason: '"$bad" must fail');
      }
    });

    test('allows an empty value when the number is optional', () {
      expect(Validators.phone('', required: false), isNull);
      expect(Validators.phone(''), isNotNull);
    });
  });

  group('Validators.messageBody', () {
    test('enforces the 1000-character cap the send route applies', () {
      expect(Validators.messageBody('a' * 1000), isNull);
      expect(Validators.messageBody('a' * 1001), contains('too long'));
    });

    test('rejects whitespace-only messages', () {
      expect(Validators.messageBody('   '), isNotNull);
    });
  });
}
