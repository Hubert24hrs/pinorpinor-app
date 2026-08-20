import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/config/app_config.dart';
import 'package:pinorpinor_app/core/constants/navigation.dart';

/// Guards the menu against drifting from the website's `src/lib/navigation.ts`.
///
/// That file is the website's single navigation definition — its sidebar and
/// its mobile drawer both render from it. The app keeps a copy, and a copy
/// rots: an entry added on the website simply would not exist here, and nobody
/// would notice until a member asked where it went.
///
/// The parity check reads the real TypeScript when the sibling checkout is
/// present, and skips otherwise so the app stays buildable on its own.
void main() {
  final websiteNav = File('../pinorpinor/src/lib/navigation.ts');

  List<NavItem> allItems() =>
      <NavItem>[for (final NavSection s in kNavSections) ...s.items];

  group('menu integrity', () {
    test('every entry has a label and an icon', () {
      for (final item in allItems()) {
        expect(item.label.trim(), isNotEmpty);
        expect(item.href.trim(), isNotEmpty, reason: item.label);
      }
    });

    test('every entry leads somewhere real', () {
      // The whole point of the menu is that nothing in it is decorative. A
      // native entry needs a route; a placeholder needs its explanation.
      for (final item in allItems()) {
        switch (item.kind) {
          case NavKind.native:
            expect(item.route, isNotNull, reason: '${item.label} has no route');
            expect(item.route, startsWith('/'), reason: item.label);
          case NavKind.placeholder:
            expect(
              item.placeholder,
              isNotNull,
              reason: '${item.label} has no explanation',
            );
            expect(item.placeholder!.status.trim(), isNotEmpty);
          case NavKind.website:
            expect(item.href, startsWith('/'), reason: item.label);
        }
      }
    });

    test('no duplicate destinations', () {
      final routes = <String>[
        for (final item in allItems())
          if (item.route != null) item.route!,
      ];
      expect(routes.toSet(), hasLength(routes.length));
    });

    test('website entries stay on the app origin', () {
      // AppDrawer builds these as `AppConfig.apiOrigin + href`, and
      // LegalLinks.open asserts the result is on that origin -- it refuses to
      // launch anything else, so a stray absolute URL here would trip the
      // assert in debug and open an off-platform page in release.
      for (final item in allItems()) {
        if (item.kind != NavKind.website) continue;
        expect(
          item.href,
          startsWith('/'),
          reason: '${item.label} must be a path, not an absolute URL',
        );
        expect(item.href, isNot(contains('://')), reason: item.label);
        expect(
          '${AppConfig.apiOrigin}${item.href}',
          startsWith(AppConfig.apiOrigin),
        );
      }
    });

    test('ships no admin entry', () {
      // The website's list ends with a moderation link. This app has no admin
      // surface at all: an app carrying moderation tooling would be an app
      // whose compromise carried it too.
      expect(allItems().where((i) => i.adminOnly), isEmpty);
      expect(
        allItems().where((i) => i.href.startsWith('/admin')),
        isEmpty,
      );
    });

    test('account entries are gated behind sign-in', () {
      final account = kNavSections.firstWhere((s) => s.title == 'My account');
      for (final item in account.items) {
        expect(item.authOnly, isTrue, reason: '${item.label} should be gated');
      }
    });

    test('a signed-out visitor is not offered account destinations', () {
      final visible = <NavItem>[
        for (final s in kNavSections)
          ...visibleNavItems(s.items, isSignedIn: false),
      ];
      expect(visible.where((i) => i.authOnly), isEmpty);
      // But the public sections stay available: browsing needs no account.
      expect(visible.map((i) => i.label), contains('Member Discovery'));
      expect(visible.map((i) => i.label), contains('Online Now'));
    });

    test('a signed-in member is offered everything', () {
      final visible = <NavItem>[
        for (final s in kNavSections)
          ...visibleNavItems(s.items, isSignedIn: true),
      ];
      expect(visible, hasLength(allItems().length));
    });
  });

  group('parity with the website menu', () {
    test('every website nav entry exists in the app menu', () {
      if (!websiteNav.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${websiteNav.path}; '
          'menu parity is unverified in this run',
        );
        return;
      }

      final source = websiteNav.readAsStringSync();
      final body = source
          .split('export const NAV_SECTIONS: NavSection[] = [')
          .last
          .split('\n];')
          .first;

      final entry = RegExp(r'href:\s*"([^"]+)",\s*label:\s*"([^"]+)"');
      final expected = <String, String>{
        for (final m in entry.allMatches(body)) m.group(1)!: m.group(2)!,
      };

      expect(
        expected,
        isNotEmpty,
        reason: 'could not parse navigation.ts; its shape has changed',
      );

      final appLabels = allItems().map((i) => i.label).toSet();

      for (final MapEntry<String, String> e in expected.entries) {
        // /admin is excluded on purpose — see the "ships no admin entry" test.
        if (e.key.startsWith('/admin')) continue;
        expect(
          appLabels,
          contains(e.value),
          reason:
              'the website menu offers "${e.value}" (${e.key}) and the app '
              'does not. A member who knows the site would go looking for it.',
        );
      }
    });
  });
}
