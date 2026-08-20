import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/navigation.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/data/models/settings.dart';
import 'package:pinorpinor_app/features/discovery/live_screen.dart';
import 'package:pinorpinor_app/features/discovery/locations_screen.dart';
import 'package:pinorpinor_app/features/discovery/videos_screen.dart';
import 'package:pinorpinor_app/features/shell/section_placeholder_screen.dart';
import 'package:pinorpinor_app/shared/widgets/profile_card.dart';

import '../helpers/fake_discovery_repository.dart';
import '../helpers/pump_app.dart';

/// The three screens added to close the menu gap, plus the placeholder.
///
/// Each is new code with no coverage, and each has four states that a member
/// can actually land in — loading, error, empty and data. The empty states
/// matter more than usual here: production currently has almost no approved
/// media, so empty is the state most people will see first, and it needs to
/// explain itself rather than look broken.
void main() {
  const routes = <String>['/home', '/discover', '/live', '/videos'];

  group('Online Now', () {
    testWidgets('renders the members it is given', (tester) async {
      final repository = FakeDiscoveryRepository(
        onlinePage: FakeDiscoveryRepository.page(<dynamic>[
          FakeDiscoveryRepository.profile('zainab', presence: 'ONLINE'),
          FakeDiscoveryRepository.profile('ada', presence: 'TODAY'),
        ].cast()),
      );

      await tester.pumpRouted(
        const LiveScreen(),
        overrides: fakeDiscoveryOverrides(repository),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileCard), findsNWidgets(2));
    });

    testWidgets('defaults to the wide window, not the strict one', (
      tester,
    ) async {
      // Strict would render an empty page most of the time on a platform this
      // young. Every member still carries their real bucket, so nothing is
      // labelled "online" that is not.
      final repository = FakeDiscoveryRepository();

      await tester.pumpRouted(
        const LiveScreen(),
        overrides: fakeDiscoveryOverrides(repository),
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(repository.lastStrict, isFalse);
    });

    testWidgets('the strict filter re-queries', (tester) async {
      final repository = FakeDiscoveryRepository();

      await tester.pumpRouted(
        const LiveScreen(),
        overrides: fakeDiscoveryOverrides(repository),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Online only'));
      await tester.pumpAndSettle();

      expect(repository.lastStrict, isTrue);
    });

    testWidgets('an empty result explains itself', (tester) async {
      await tester.pumpRouted(
        const LiveScreen(),
        overrides: fakeDiscoveryOverrides(FakeDiscoveryRepository()),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nobody has been active recently'),
        findsOneWidget,
      );
    });

    testWidgets('a failure offers a retry rather than a blank screen', (
      tester,
    ) async {
      await tester.pumpRouted(
        const LiveScreen(),
        overrides: fakeDiscoveryOverrides(
          FakeDiscoveryRepository(
            error: const ApiException(
              kind: ApiErrorKind.network,
              message: "You're offline. Reconnect and try again.",
            ),
          ),
        ),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsWidgets);
    });
  });

  group('Videos', () {
    testWidgets('collects videos across profiles', (tester) async {
      final repository = FakeDiscoveryRepository(
        browsePages: <dynamic>[
          FakeDiscoveryRepository.page(
            <dynamic>[
              FakeDiscoveryRepository.profile(
                'zainab',
                media: <Map<String, dynamic>>[
                  FakeDiscoveryRepository.video('v1'),
                ],
              ),
              FakeDiscoveryRepository.profile(
                'ada',
                media: <Map<String, dynamic>>[
                  FakeDiscoveryRepository.video('v2'),
                ],
              ),
            ].cast(),
          ),
        ].cast(),
      );

      await tester.pumpRouted(
        const VideosScreen(),
        overrides: fakeDiscoveryOverrides(repository),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      // Not pumpAndSettle: these tiles carry a network image, which never
      // resolves under test, so the tree never reaches a settled state.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNWidgets(2));
    });

    testWidgets('a profile appearing twice does not render twice', (
      tester,
    ) async {
      // The feed shifts under paging, so the same profile can surface on more
      // than one page. De-duplication is on the media id.
      final duplicated = FakeDiscoveryRepository.page(
        <dynamic>[
          FakeDiscoveryRepository.profile(
            'zainab',
            media: <Map<String, dynamic>>[FakeDiscoveryRepository.video('v1')],
          ),
        ].cast(),
        totalPages: 3,
      );

      await tester.pumpRouted(
        const VideosScreen(),
        overrides: fakeDiscoveryOverrides(
          FakeDiscoveryRepository(
            browsePages: <dynamic>[duplicated].cast(),
          ),
        ),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    });

    testWidgets('stops sweeping at the last page', (tester) async {
      // totalPages: 1 means one request, not the three-page ceiling.
      final repository = FakeDiscoveryRepository(
        browsePages: <dynamic>[
          FakeDiscoveryRepository.page(const <dynamic>[].cast()),
        ].cast(),
      );

      await tester.pumpRouted(
        const VideosScreen(),
        overrides: fakeDiscoveryOverrides(repository),
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(repository.browseCalls, 1);
    });

    testWidgets('says so when there are no videos', (tester) async {
      await tester.pumpRouted(
        const VideosScreen(),
        overrides: fakeDiscoveryOverrides(FakeDiscoveryRepository()),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(find.text('No videos yet'), findsOneWidget);
    });
  });

  group('Locations', () {
    testWidgets('lists cities with their counts', (tester) async {
      await tester.pumpRouted(
        const LocationsScreen(),
        overrides: fakeDiscoveryOverrides(
          FakeDiscoveryRepository(
            cities: const <LocationCount>[
              LocationCount(city: 'Lagos', count: 12),
              LocationCount(city: 'Abuja', count: 3),
            ],
          ),
        ),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(find.text('Lagos'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Abuja'), findsOneWidget);
    });

    testWidgets('an empty list explains itself', (tester) async {
      await tester.pumpRouted(
        const LocationsScreen(),
        overrides: fakeDiscoveryOverrides(FakeDiscoveryRepository()),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(find.text('No cities to show yet'), findsOneWidget);
    });
  });

  group('Section placeholder', () {
    testWidgets('shows the website\'s own explanation', (tester) async {
      const copy = SectionPlaceholderCopy(
        title: 'Events',
        intro: 'Member and venue events.',
        status: 'No Event model exists yet.',
      );

      await tester.pumpRouted(
        const SectionPlaceholderScreen(copy: copy),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(find.text('Events'), findsWidgets);
      expect(find.text('Member and venue events.'), findsOneWidget);
      expect(find.text('Why this is empty'), findsOneWidget);
      expect(find.text('No Event model exists yet.'), findsOneWidget);
    });

    testWidgets('offers a way onward rather than dead-ending', (tester) async {
      await tester.pumpRouted(
        const SectionPlaceholderScreen(
          copy: SectionPlaceholderCopy(
            title: 'Rooms',
            intro: 'Group conversations.',
            status: 'Not built.',
          ),
        ),
        surfaceSize: TestDevices.tablet,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(find.text('Browse members instead'), findsOneWidget);
    });

    testWidgets('lays out without overflow at 320px', (tester) async {
      await tester.pumpRouted(
        const SectionPlaceholderScreen(
          copy: SectionPlaceholderCopy(
            title: 'Feeds',
            intro: 'A running feed of posts from members you follow.',
            status:
                'There is no Post table in the database yet, so there is '
                'nothing this page could load.',
          ),
        ),
        surfaceSize: TestDevices.smallPhone,
        stubRoutes: routes,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
