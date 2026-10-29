import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/navigation.dart';
import 'package:pinorpinor_app/core/routing/app_routes.dart';
import 'package:pinorpinor_app/core/routing/deep_links.dart';
import 'package:pinorpinor_app/features/content/about_screen.dart';
import 'package:pinorpinor_app/features/content/faq_screen.dart';
import 'package:pinorpinor_app/features/content/privacy_screen.dart';
import 'package:pinorpinor_app/features/content/safety_screen.dart';
import 'package:pinorpinor_app/features/content/terms_screen.dart';

import '../helpers/pump_app.dart';

/// The five editorial pages brought in-app on 2026-10-29, plus the guard that
/// stops them reintroducing a rule the platform deleted.
void main() {
  /// Tall enough to lay out a whole content page.
  ///
  /// These screens are lazy `ListView`s, so on a phone-sized surface anything
  /// past the fold is never built and `findsNothing` would pass for text that
  /// is simply further down. Every assertion below is about copy, not layout,
  /// so the page is given room rather than scrolled to each target.
  const Size tall = Size(1000, 6000);

  group('every content screen renders', () {
    testWidgets('About', (tester) async {
      await tester.pumpScreen(const AboutScreen(), surfaceSize: tall);
      expect(find.text('Our Vision & Platform Mission'), findsOneWidget);
      expect(find.textContaining('Key Platform Pillars'), findsOneWidget);
    });

    testWidgets('Safety', (tester) async {
      await tester.pumpScreen(const SafetyScreen(), surfaceSize: tall);
      expect(find.text('Pinorpinor Safety Centre'), findsOneWidget);
      // All four numbered pillars, and the guidance block below them.
      for (final n in <String>['01', '02', '03', '04']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('Safe First Meeting Guidance'), findsOneWidget);
      expect(find.text('Report an account'), findsOneWidget);
    });

    testWidgets('FAQ', (tester) async {
      await tester.pumpScreen(const FaqScreen(), surfaceSize: tall);
      expect(find.text('Frequently asked questions'), findsOneWidget);
      expect(find.text('Do I need an account to browse?'), findsOneWidget);
    });

    testWidgets('Privacy', (tester) async {
      await tester.pumpScreen(const PrivacyScreen(), surfaceSize: tall);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.textContaining('1. Information We Collect'), findsOneWidget);
    });

    testWidgets('Terms', (tester) async {
      await tester.pumpScreen(const TermsScreen(), surfaceSize: tall);
      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.textContaining('3. Prohibited Conduct'), findsOneWidget);
    });
  });

  group('the deleted consent flow stays deleted', () {
    /// Wording that described asking, accepting or declining a contact
    /// request. The flow was removed on 2026-08-23; the app's own copy still
    /// described it on four screens two months later, and the website's FAQ
    /// describes it today.
    ///
    /// These screens are transcribed from that website copy, which makes them
    /// the most likely place for it to come back.
    const List<String> forbidden = <String>[
      'contact request',
      'accept or decline',
      'you accept',
      'asks to contact you',
      'until you accept',
    ];

    testWidgets('no content screen offers a consent gate that does not exist', (
      tester,
    ) async {
      for (final screen in <(String, Widget Function())>[
        ('About', AboutScreen.new),
        ('Safety', SafetyScreen.new),
        ('FAQ', FaqScreen.new),
        ('Privacy', PrivacyScreen.new),
        ('Terms', TermsScreen.new),
      ]) {
        await tester.pumpScreen(screen.$2(), surfaceSize: tall);

        final String rendered = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
            .join(' ')
            .toLowerCase();

        for (final phrase in forbidden) {
          expect(
            rendered.contains(phrase),
            isFalse,
            reason:
                '${screen.$1} says "$phrase". Nobody asks to reach anybody '
                'now: a chat is opened by paying for it, and both sides are '
                'charged. Telling a member a consent gate protects her when '
                'none exists is the one thing this copy must never do.',
          );
        }
      }
    });

    testWidgets('the FAQ answers what credits are actually for', (
      tester,
    ) async {
      await tester.pumpScreen(const FaqScreen(), surfaceSize: tall);

      // The question is present...
      final question = find.text('What are credits for?');
      expect(question, findsOneWidget);

      await tester.ensureVisible(question);
      await tester.pumpAndSettle();
      await tester.tap(question);
      await tester.pumpAndSettle();

      // ...and its answer names opening a chat, not boosts alone. The
      // website's version mentions only boosts, which is now the secondary
      // use and not the one that makes a member reachable.
      expect(find.textContaining('Opening a WhatsApp chat'), findsOneWidget);
    });
  });

  group('the sections are reachable', () {
    test('each new path resolves to its screen rather than a profile', () {
      // Every one of these is a valid username shape, so a missing case opens
      // a profile lookup for a member called "safety".
      // Both link forms a member can actually arrive by: the website's own
      // URL, and the app's custom scheme.
      for (final (path, route) in <(String, String)>[
        ('about', AppRoutes.about),
        ('faq', AppRoutes.faq),
        ('safety', AppRoutes.safety),
        ('privacy', AppRoutes.privacy),
        ('terms', AppRoutes.terms),
        ('report-abuse', AppRoutes.reportAbuse),
      ]) {
        expect(
          DeepLinks.resolve(Uri.parse('https://pinorpinor.com/$path')),
          route,
          reason: 'a website link to /$path should open the screen',
        );
        expect(
          DeepLinks.resolve(Uri.parse('pinorpinor://$path')),
          route,
          reason: 'the custom scheme should reach /$path too',
        );
      }
    });

    test('Safety and FAQ are native menu entries, not browser handovers', () {
      NavItem find(String href) =>
          kNavSections.expand((s) => s.items).firstWhere((i) => i.href == href);

      for (final href in <String>['/safety', '/faq']) {
        final item = find(href);
        expect(
          item.kind,
          NavKind.native,
          reason: '$href should open in the app now',
        );
        expect(item.route, isNotNull);
      }
    });

    test('Exclusive and Reviews are still declined, on purpose', () {
      // Neither has a REST endpoint: /exclusive reads Prisma directly for
      // live-boosted members, and prisma.review has no route at all. Any
      // client-side approximation shows the wrong people in the wrong order,
      // so these stay on the web until the website exposes them.
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/exclusive')),
        isNull,
      );
      expect(
        DeepLinks.resolve(Uri.parse('https://pinorpinor.com/reviews')),
        isNull,
      );
    });
  });

  group('transcription is faithful where it is meant to be', () {
    final File safety = File('../pinorpinor/src/app/safety/page.tsx');

    testWidgets('the Safety screen keeps the website\'s own four pillars', (
      tester,
    ) async {
      if (!safety.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${safety.path}; the Safety '
          'transcription is unverified in this run',
        );
        return;
      }

      final String source = safety.readAsStringSync();
      await tester.pumpScreen(const SafetyScreen(), surfaceSize: tall);

      // Headings only: the prose is reflowed for a phone, but a pillar
      // disappearing from the website should fail here.
      for (final heading in <String>[
        'Adults Only, 18+',
        'Human Profile Moderation',
        'Location Privacy Protection',
        'Zero Commercial Exploitation',
      ]) {
        expect(
          source.contains(heading),
          isTrue,
          reason: '"$heading" has gone from the website; this screen is stale',
        );
        expect(find.text(heading), findsOneWidget);
      }
    });
  });
}
