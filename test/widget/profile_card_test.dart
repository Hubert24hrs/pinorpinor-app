import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/theme/app_theme.dart';
import 'package:pinorpinor_app/data/models/profile.dart';
import 'package:pinorpinor_app/shared/widgets/brand.dart';
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
  }) => ProfileSummary.fromJson(<String, dynamic>{
    'id': 'u1',
    'username': name.toLowerCase(),
    'displayName': name,
    'age': age,
    'verificationStatus': verified ? 'VERIFIED' : 'NONE',
    'datingProfile': <String, dynamic>{
      'city': city,
      'isAvailableToday': availableToday,
      'isRedHot': redHot,
      'isFeatured': featured,
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

    testWidgets('shows the boosted badge for a red-hot profile', (
      tester,
    ) async {
      await tester.pumpApp(ProfileCard(profile: profile(redHot: true)));
      expect(find.text('Red hot'), findsOneWidget);
    });

    testWidgets('a featured profile shows New unless it is also boosted', (
      tester,
    ) async {
      await tester.pumpApp(ProfileCard(profile: profile(featured: true)));
      expect(find.text('New'), findsOneWidget);

      // Both flags set: the paid boost wins, so the card does not stack two
      // gold badges on top of each other.
      await tester.pumpApp(
        ProfileCard(profile: profile(featured: true, redHot: true)),
      );
      expect(find.text('New'), findsNothing);
      expect(find.text('Red hot'), findsOneWidget);
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
