import 'dart:io';

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
      // `live` was in this list until the app grew an Online Now screen. It is
      // now claimed — see "the sections the app now owns" below. Anything that
      // remains here is content the app genuinely does not reproduce.
      for (final path in <String>[
        'about',
        'privacy',
        'terms',
        'safety',
        'contact',
        'faq',
        'reviews',
        'exclusive',
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

    test('guards every screen whose endpoint requires a session', () {
      // Saved profiles is the one that bit: /api/favorites requires auth, so
      // without a guard a signed-out visitor reaching it by deep link is told
      // their session expired rather than being asked to sign in.
      expect(AppRoutes.isProtected(AppRoutes.favorites), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.matches), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.swipe), isTrue);
    });

    test('leaves the public sections open', () {
      // These are backed by /api/public/* and work signed out, like browsing.
      // Guarding them would put a sign-in wall where the website has none.
      expect(AppRoutes.isProtected(AppRoutes.live), isFalse);
      expect(AppRoutes.isProtected(AppRoutes.videos), isFalse);
      expect(AppRoutes.isProtected(AppRoutes.locations), isFalse);
    });

    test('recognises auth-only locations', () {
      expect(AppRoutes.isAuthOnly('/login'), isTrue);
      expect(AppRoutes.isAuthOnly('/join'), isTrue);
      expect(AppRoutes.isAuthOnly('/home'), isFalse);
    });
  });

  group('every website section is accounted for', () {
    // The real hazard, and the reason this group reads the filesystem: every
    // website section slug is a valid username shape (^[a-z0-9_]{3,20}$). A
    // slug with no explicit case falls through to the username branch and
    // opens a profile lookup for a member who does not exist, so
    // pinorpinor.com/faq lands on "profile not found" rather than the FAQ.
    //
    // This shipped: /videos, /faq, /events, /rooms and /feeds all misrouted
    // that way, and /live and /locations returned null after the app had grown
    // screens for both.
    final websiteApp = Directory('../pinorpinor/src/app');

    test('no website page silently resolves to a bogus profile', () {
      if (!websiteApp.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${websiteApp.path}; '
          'deep-link coverage is unverified in this run',
        );
        return;
      }

      // Top-level route directories, which is what a shared link looks like.
      final slugs = websiteApp
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(RegExp(r'[\/]')).last)
          .where((name) =>
              !name.startsWith('[') &&
              !name.startsWith('(') &&
              !name.startsWith('_') &&
              name != 'api' &&
              name != 'admin')
          .toList();

      expect(slugs, isNotEmpty, reason: 'could not read the website pages');

      final misrouted = <String>[];
      for (final slug in slugs) {
        final resolved = DeepLinks.resolve(
          Uri.parse('https://pinorpinor.com/$slug'),
        );
        // Either the app claims it deliberately, or it declines it deliberately
        // (null, meaning the link stays on the web). What must never happen is
        // it resolving to a profile route for the slug itself.
        if (resolved != null && resolved == AppRoutes.profileFor(slug)) {
          misrouted.add(slug);
        }
      }

      expect(
        misrouted,
        isEmpty,
        reason:
            'these website sections resolve to a profile lookup for a member '
            'of the same name, so the link lands on "profile not found": '
            '$misrouted. Add an explicit case in DeepLinks.resolve.',
      );
    });
  });

  group('the sections the app now owns', () {
    test('opens Live, Videos and Locations in the app', () {
      // All three returned null, or misrouted, before the app had screens.
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/live')),
        AppRoutes.live,
      );
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/videos')),
        AppRoutes.videos,
      );
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/locations')),
        AppRoutes.locations,
      );
    });

    test('maps the website dashboard onto the app account hub', () {
      // Different names for the same place.
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/dashboard')),
        AppRoutes.account,
      );
    });

    test('still declines the sections the website has not built', () {
      for (final slug in <String>['feeds', 'events', 'rooms', 'adverts']) {
        expect(
          DeepLinks.resolve(Uri.parse('https://pinorpinor.com/$slug')),
          isNull,
          reason: '$slug does not exist on the website either',
        );
      }
    });

    test('a real username still resolves to a profile', () {
      // The default branch must keep working; the fix above must not have
      // swallowed it.
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/zainab_lagos')),
        AppRoutes.profileFor('zainab_lagos'),
      );
    });
  });
}
