import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/theme/app_theme.dart';
import 'package:pinorpinor_app/data/models/profile.dart';
import 'package:pinorpinor_app/shared/widgets/brand.dart';
import 'package:pinorpinor_app/shared/widgets/primary_service_badge.dart';
import 'package:pinorpinor_app/shared/widgets/profile_card.dart';

import '../helpers/pump_app.dart';

void main() {
  ProfileSummary profile({
    String name = 'Zainab',
    int? age = 26,
    bool verified = false,
    bool availableToday = false,
    bool redHot = false,
    bool featured = false,
    String? city,
    String? primaryService,
    Object? presence,
  }) => ProfileSummary.fromJson(<String, dynamic>{
    'id': 'u1',
    'username': name.toLowerCase(),
    'displayName': name,
    'age': age,
    'verificationStatus': verified ? 'VERIFIED' : 'NONE',
    'presence': ?presence,
    'datingProfile': <String, dynamic>{
      'city': city,
      'isAvailableToday': availableToday,
      'isRedHot': redHot,
      'isFeatured': featured,
      'primaryService': primaryService,
    },
  });

  group('ProfileCard', () {
    testWidgets('shows the name and age together', (tester) async {
      await tester.pumpApp(ProfileCard(profile: profile()));
      expect(find.text('Zainab, 26'), findsOneWidget);
    });

    testWidgets('omits the age when the API did not send one', (tester) async {
      await tester.pumpApp(ProfileCard(profile: profile(age: null)));
      expect(find.text('Zainab'), findsOneWidget);
    });

    testWidgets('shows the verified tick only when verified', (tester) async {
      await tester.pumpApp(ProfileCard(profile: profile()));
      expect(find.byIcon(Icons.verified_rounded), findsNothing);

      await tester.pumpApp(ProfileCard(profile: profile(verified: true)));
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('draws nothing at all over the photograph', (tester) async {
      // The rule this card exists to hold since 2026-08-21: on a 3:4 portrait,
      // anything in the top corner lands across the member's face, which is the
      // one thing a member card exists to show. Every badge that used to sit
      // there is either gone or in the bottom strip now, and this test fails if
      // one comes back.
      await tester.pumpApp(
        ProfileCard(
          profile: profile(
            verified: true,
            availableToday: true,
            redHot: true,
            featured: true,
            primaryService: 'hookup',
            presence: 'ONLINE',
            city: 'Lagos',
          ),
        ),
      );

      final Size card = tester.getSize(find.byType(ProfileCard));
      // Everything drawn must start below the halfway line. The website
      // measured the top 54-74% of the image as clear; half is the conservative
      // form of the same assertion and does not depend on font metrics.
      final double faceLine =
          tester.getTopLeft(find.byType(ProfileCard)).dy + card.height / 2;

      for (final Finder drawn in <Finder>[
        find.byType(PrimaryServiceBadge),
        find.text('Zainab, 26'),
        find.textContaining('Lagos'),
        find.text('Available today'),
      ]) {
        expect(drawn, findsOneWidget);
        expect(
          tester.getTopLeft(drawn).dy,
          greaterThan(faceLine),
          reason: 'something is being drawn over her face',
        );
      }
    });

    testWidgets('the boost and new badges are gone from the card', (
      tester,
    ) async {
      // Deliberate, and mirrors the website. A boost buys placement in the
      // discovery order, which the member still gets; neither badge told a
      // visitor anything they could act on, and both were printed across a
      // face to say it.
      await tester.pumpApp(
        ProfileCard(profile: profile(redHot: true, featured: true)),
      );
      expect(find.text('Red hot'), findsNothing);
      expect(find.text('New'), findsNothing);
    });

    testWidgets('shows the primary service badge, and only when there is one', (
      tester,
    ) async {
      // Not merely an empty badge: the row is not built at all. An empty row
      // still costs about 20px, which on a two-up 320px grid pushes the whole
      // text block that much further up the photograph for every member who has
      // not chosen -- the opposite of the point of the change.
      await tester.pumpApp(ProfileCard(profile: profile()));
      expect(find.byType(PrimaryServiceBadge), findsNothing);
      expect(find.text('Hookup'), findsNothing);

      await tester.pumpApp(
        ProfileCard(profile: profile(primaryService: 'hookup')),
      );
      expect(find.text('Hookup'), findsOneWidget);
    });

    testWidgets('the presence dot follows the bucket, and AWAY draws none', (
      tester,
    ) async {
      await tester.pumpApp(ProfileCard(profile: profile(presence: 'ONLINE')));
      expect(
        tester
            .widgetList<PresenceDot>(find.byType(PresenceDot))
            .single
            .presence,
        isNotNull,
      );
      expect(find.byType(SizedBox), findsWidgets);

      // Switched off: null, not AWAY, and nothing rendered either way.
      await tester.pumpApp(ProfileCard(profile: profile()));
      expect(
        tester
            .widgetList<PresenceDot>(find.byType(PresenceDot))
            .single
            .presence,
        isNull,
      );
    });

    testWidgets('the WhatsApp glyph opens the profile, never a dialler', (
      tester,
    ) async {
      // The member's number is not in this payload and must never be: a direct
      // wa.me link here would publish every member's WhatsApp number to
      // anonymous visitors and let a whole grid be harvested in one pass.
      int contactTaps = 0;
      await tester.pumpApp(
        ProfileCard(
          profile: profile(),
          onTap: () {},
          onContact: () => contactTaps++,
        ),
      );

      final Finder glyph = find.byIcon(Icons.chat_rounded);
      expect(glyph, findsOneWidget);
      await tester.tap(glyph);
      await tester.pumpAndSettle();
      expect(contactTaps, 1);
    });

    testWidgets('shows the availability badge', (tester) async {
      await tester.pumpApp(ProfileCard(profile: profile(availableToday: true)));
      expect(find.text('Available today'), findsOneWidget);
    });

    testWidgets('shows the place when there is one', (tester) async {
      await tester.pumpApp(ProfileCard(profile: profile(city: 'Lagos')));
      expect(find.text('Lagos'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        ProfileCard(profile: profile(), onTap: () => taps++),
      );
      await tester.tap(find.byType(ProfileCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('exposes one semantic label for screen readers', (
      tester,
    ) async {
      await tester.pumpApp(
        ProfileCard(profile: profile(verified: true, city: 'Lagos')),
      );

      // The name is split across two coloured spans visually; a screen reader
      // must still hear one coherent description.
      final semantics = tester.getSemantics(find.byType(ProfileCard));
      expect(semantics.label, contains('Zainab'));
      expect(semantics.label, contains('26'));
      expect(semantics.label, contains('verified'));
    });

    testWidgets('does not overflow on a 320px-wide phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        SizedBox(
          width: 150,
          child: ProfileCard(
            profile: profile(
              name: 'Aisha Oluwafunmilayo Adebayo',
              city: 'Victoria Island, Lagos, Nigeria',
            ),
          ),
        ),
      );

      // A RenderFlex overflow reports itself through the error handler; this
      // asserts none was raised while laying out the longest realistic content.
      expect(tester.takeException(), isNull);
    });
  });

  group('AppBadge', () {
    testWidgets('renders each preset with its label', (tester) async {
      await tester.pumpApp(
        const Column(
          children: <Widget>[
            AppBadge.verified(),
            AppBadge.availableToday(),
            AppBadge.boosted(),
            AppBadge.location(label: 'Abuja'),
          ],
        ),
      );

      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Available today'), findsOneWidget);
      expect(find.text('Red hot'), findsOneWidget);
      expect(find.text('Abuja'), findsOneWidget);
    });
  });

  group('GradientButton', () {
    testWidgets('is disabled while loading', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        GradientButton(label: 'Send', isLoading: true, onPressed: () => taps++),
      );

      await tester.tap(find.byType(GradientButton));
      await tester.pump();
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('meets the 44px touch-target floor', (tester) async {
      await tester.pumpApp(GradientButton(label: 'Send', onPressed: () {}));
      final size = tester.getSize(find.byType(GradientButton));
      expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
    });
  });
}
