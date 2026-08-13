import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/routing/app_routes.dart';
import 'package:pinorpinor_app/core/routing/deep_links.dart';

/// Deep links arrive from outside the app, so the resolver is a trust boundary.
/// These tests assert the two properties that matter: it maps the links the app
/// claims, and it returns null — never an external destination — for anything
/// else.
void main() {
  group('DeepLinks.resolve — custom scheme', () {
    test('maps a profile link', () {
      expect(
        DeepLinks.resolve(Uri.parse('pinorpinor://profile/zainab')),
        '${AppRoutes.profile}/zainab',
      );
    });

    test('maps a conversation link', () {
      expect(
        DeepLinks.resolve(Uri.parse('pinorpinor://conversation/abc123')),
        '${AppRoutes.conversation}/abc123',
      );
    });

    test('maps the tab-level links', () {
      expect(
        DeepLinks.resolve(Uri.parse('pinorpinor://notifications')),
        AppRoutes.notifications,
      );
      expect(
        DeepLinks.resolve(Uri.parse('pinorpinor://discover')),
        AppRoutes.discover,
      );
      expect(
        DeepLinks.resolve(Uri.parse('pinorpinor://credits')),
        AppRoutes.credits,
      );
    });

    test('a bare scheme lands on home', () {
      expect(DeepLinks.resolve(Uri.parse('pinorpinor://')), AppRoutes.home);
    });
  });

  group('DeepLinks.resolve — https app links', () {
    test('maps a bare username, as the website serves it', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/zainab_lagos')),
        '${AppRoutes.profile}/zainab_lagos',
      );
    });

    test('accepts the www host too', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://www.pinorpinor.com/profile/ada')),
        '${AppRoutes.profile}/ada',
      );
    });

    test('carries a password-reset token through to the reset screen', () {
      final resolved = DeepLinks.resolve(
        Uri.parse('https://pinorpinor.com/reset-password?token=abc123'),
      );
      expect(resolved, startsWith(AppRoutes.resetPassword));
      expect(resolved, contains('token=abc123'));
    });

    test('a reset link with no token falls back to requesting one', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/reset-password')),
        AppRoutes.forgotPassword,
      );
    });

    test('marketing and legal pages stay on the web', () {
      for (final path in <String>[
        'about',
        'privacy',
        'terms',
        'safety',
        'live',
      ]) {
        expect(
          DeepLinks.resolve(Uri.parse('https://pinorpinor.com/$path')),
          isNull,
          reason: '/$path has no app equivalent',
        );
      }
    });
  });

  group('DeepLinks.resolve — rejects what it does not own', () {
    test('another origin', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://evil.example.com/zainab')),
        isNull,
      );
      // A lookalike host must not match.
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com.evil.example/x')),
        isNull,
      );
    });

    test('another scheme', () {
      expect(DeepLinks.resolve(Uri.parse('javascript:alert(1)')), isNull);
      expect(DeepLinks.resolve(Uri.parse('file:///etc/passwd')), isNull);
      expect(
        DeepLinks.resolve(Uri.parse('http://pinorpinor.com/zainab')),
        isNull,
      );
    });

    test('a path segment that could not be a username', () {
      // Usernames are ^[a-z0-9_]{3,20}$ at the database level, so anything
      // outside that is not a profile link and must not be treated as one.
      for (final path in <String>['a', 'Zainab-Lagos', 'a' * 21, 'x!y']) {
        expect(
          DeepLinks.resolve(Uri.parse('https://pinorpinor.com/$path')),
          isNull,
          reason: '"$path" is not a username',
        );
      }
    });

    test('a traversal segment collapses to a safe in-app route', () {
      // `Uri` normalises `..` away before the resolver sees it, so the link
      // degrades to the app's own home rather than escaping anywhere. Asserted
      // explicitly because "it happens to be safe" is worth pinning down.
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/..')),
        AppRoutes.home,
      );
    });

    test('never produces a destination outside the app route table', () {
      final probes = <String>[
        'pinorpinor://profile/../../admin',
        'pinorpinor://profile/%2e%2e%2fadmin',
        'https://pinorpinor.com/profile/../settings',
      ];

      for (final probe in probes) {
        final resolved = DeepLinks.resolve(Uri.parse(probe));
        if (resolved == null) continue;
        expect(resolved, startsWith('/'), reason: probe);
        expect(resolved, isNot(contains('://')), reason: probe);
        // A traversal attempt must not escape the profile segment.
        expect(
          resolved.startsWith('${AppRoutes.profile}/') ||
              AppRoutes.protectedPrefixes.contains(resolved) ||
              resolved == AppRoutes.discover ||
              resolved == AppRoutes.home,
          isTrue,
          reason: '$probe resolved to $resolved',
        );
      }
    });
  });

  group('AppRoutes guards', () {
    test('recognises protected locations', () {
      expect(AppRoutes.isProtected('/messages'), isTrue);
      expect(AppRoutes.isProtected('/conversation/abc'), isTrue);
      expect(AppRoutes.isProtected('/settings/account'), isTrue);
      expect(AppRoutes.isProtected('/me/edit'), isTrue);
    });

    test('leaves public browsing open', () {
      // The website has no login wall for browsing and the app keeps that.
      expect(AppRoutes.isProtected('/home'), isFalse);
      expect(AppRoutes.isProtected('/discover'), isFalse);
      expect(AppRoutes.isProtected('/profile/zainab'), isFalse);
    });

    test('recognises auth-only locations', () {
      expect(AppRoutes.isAuthOnly('/login'), isTrue);
      expect(AppRoutes.isAuthOnly('/join'), isTrue);
      expect(AppRoutes.isAuthOnly('/home'), isFalse);
    });
  });
}
