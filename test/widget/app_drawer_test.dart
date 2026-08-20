import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/features/auth/auth_controller.dart';
import 'package:pinorpinor_app/core/constants/navigation.dart';
import 'package:pinorpinor_app/features/shell/app_drawer.dart';
import 'package:pinorpinor_app/features/shell/section_placeholder_screen.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

/// The menu is the app's map of the platform, so what it offers — and to whom —
/// is worth asserting directly.
///
/// The app shipped for weeks with five tabs and no menu at all, which made most
/// of the website unreachable from a phone. These tests exist so that cannot
/// quietly happen again.
void main() {
  Future<void> pumpDrawer(
    WidgetTester tester, {
    required bool signedIn,
    Size? size,
  }) async {
    final repository = FakeAuthRepository();
    await tester.pumpRouted(
      Builder(
        builder: (context) => Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(title: const Text('Host')),
          body: const SizedBox.shrink(),
        ),
      ),
      overrides: fakeAuthOverrides(repository),
      surfaceSize: size ?? TestDevices.tablet,
      stubRoutes: const <String>[
        '/home',
        '/discover',
        '/live',
        '/videos',
        '/locations',
        '/messages',
        '/notifications',
        '/me',
        '/favorites',
        '/settings',
        '/login',
      ],
    );

    if (signedIn) {
      // Sign in through the real controller so the drawer sees a session,
      // rather than stubbing the boolean it reads.
      final element = tester.element(find.byType(Scaffold).first);
      final container = ProviderScope.containerOf(element);
      await container
          .read(authControllerProvider.notifier)
          .signIn(identifier: 'member', password: 'password123');
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens and shows the public sections', (tester) async {
    await pumpDrawer(tester, signedIn: false);

    // The first group needs no heading on the website, and none here.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Online Now'), findsOneWidget);
    expect(find.text('Member Discovery'), findsOneWidget);
    expect(find.text('Exclusive'), findsOneWidget);
  });

  testWidgets('shows the Explore and Community headings', (tester) async {
    await pumpDrawer(tester, signedIn: false);

    expect(find.text('EXPLORE'), findsOneWidget);
    expect(find.text('COMMUNITY'), findsOneWidget);
  });

  testWidgets('a signed-out visitor is not offered account destinations', (
    tester,
  ) async {
    await pumpDrawer(tester, signedIn: false);

    // Browsing needs no account, so the public entries stay.
    expect(find.text('Member Discovery'), findsOneWidget);
    // These would bounce them to sign-in, so they are not offered.
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Saved profiles'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    // Instead they get the way in — at the foot of the list, so scroll to it.
    final signIn = find.text('Sign in');
    await tester.scrollUntilVisible(signIn, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(signIn, findsWidgets);
  });

  testWidgets('never offers a moderation entry', (tester) async {
    // The website's menu ends with one. This app ships no admin surface, and
    // an app that carried moderation tooling would be an app whose compromise
    // carried it too.
    await pumpDrawer(tester, signedIn: false);

    expect(find.text('Moderation'), findsNothing);
    expect(find.textContaining('Admin'), findsNothing);
  });

  testWidgets('website entries are marked as leaving the app', (tester) async {
    await pumpDrawer(tester, signedIn: false);

    // FAQ, Safety, Reviews, Exclusive and Contact open the real page. The glyph
    // is there so nobody is surprised to find themselves in a browser.
    expect(find.byIcon(Icons.open_in_new_rounded), findsWidgets);
  });

  testWidgets('a placeholder entry explains itself rather than dead-ending', (
    tester,
  ) async {
    await pumpDrawer(tester, signedIn: false);

    final rooms = find.text('Rooms');
    await tester.ensureVisible(rooms);
    await tester.pumpAndSettle();
    await tester.tap(rooms);
    await tester.pumpAndSettle();

    expect(find.byType(SectionPlaceholderScreen), findsOneWidget);
    expect(find.text('Why this is empty'), findsOneWidget);
    // The website's own wording, so the two never disagree.
    expect(find.textContaining('strictly one-to-one'), findsOneWidget);
  });

  testWidgets('every placeholder in the menu has real copy', (tester) async {
    // A placeholder with an empty explanation would be a dead end wearing a
    // hat. Checked against the definition rather than the rendered tree so
    // every entry is covered, not just the visible ones.
    final placeholders = <NavItem>[
      for (final section in kNavSections)
        for (final item in section.items)
          if (item.kind == NavKind.placeholder) item,
    ];

    expect(placeholders, isNotEmpty);
    for (final item in placeholders) {
      expect(item.placeholder, isNotNull, reason: item.label);
      expect(item.placeholder!.intro.trim(), isNotEmpty, reason: item.label);
      expect(item.placeholder!.status.trim(), isNotEmpty, reason: item.label);
    }
  });

  testWidgets('a signed-in member is offered the account section', (
    tester,
  ) async {
    await pumpDrawer(tester, signedIn: true);

    // The account group is last in the list, so scroll it into view.
    final heading = find.text('MY ACCOUNT');
    await tester.scrollUntilVisible(
      heading,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(heading, findsOneWidget);
    expect(find.text('Saved profiles'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    // And a signed-in member is not shown the sign-in button.
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('lays out without overflow at 320px', (tester) async {
    await pumpDrawer(tester, signedIn: false, size: TestDevices.smallPhone);
    expect(tester.takeException(), isNull);
  });
}
