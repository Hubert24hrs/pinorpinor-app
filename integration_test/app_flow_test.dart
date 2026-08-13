import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pinorpinor_app/app.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/models/profile.dart';
import 'package:pinorpinor_app/data/models/settings.dart';
import 'package:pinorpinor_app/data/repositories/discovery_repository.dart';
import 'package:pinorpinor_app/data/repositories/profile_repository.dart';

/// End-to-end flows through the real app widget, with the network replaced.
///
/// Run on a connected device or emulator:
///
///     flutter test integration_test/app_flow_test.dart
///
/// **What this does and does not prove.** It exercises the app's own wiring —
/// launch, routing, the auth redirect, discovery paging, navigation into a
/// profile — against a scripted backend. It deliberately does *not* hit
/// production: a suite that created real accounts and real reports on a live
/// platform with real members would be worse than no suite at all. Verifying
/// the API contracts themselves is a separate, manual exercise against a
/// staging origin, described in docs/DEPLOYMENT.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer? container;

  tearDown(() {
    container?.dispose();
    container = null;
  });

  Future<void> launchApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // A store with no cookie: the app starts signed out, which is the
          // state most visitors arrive in.
          sessionStoreProvider.overrideWithValue(SessionStore()),
          discoveryRepositoryProvider.overrideWithValue(_ScriptedDiscovery()),
          profileRepositoryProvider.overrideWithValue(_ScriptedProfiles()),
        ],
        child: const PinorpinorApp(),
      ),
    );
    // Splash → session restore → home.
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('launches into browsable home without an account', (
    tester,
  ) async {
    await launchApp(tester);

    // The website has no login wall for browsing, and neither does the app.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Discover'), findsWidgets);
  });

  testWidgets('a signed-out visitor can browse discovery', (tester) async {
    await launchApp(tester);

    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Zainab, 26'), findsWidgets);
  });

  testWidgets('opening a profile shows the consent-gated contact button', (
    tester,
  ) async {
    await launchApp(tester);

    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Zainab, 26').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Signed out, the button says so rather than pretending contact is
    // available — the number is never resolvable without an accepted request.
    expect(find.textContaining('request contact'), findsWidgets);
    expect(find.textContaining('never shown here'), findsOneWidget);
  });

  testWidgets('a protected tab redirects a signed-out visitor to sign in', (
    tester,
  ) async {
    await launchApp(tester);

    await tester.tap(find.text('Messages').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('the sign-in screen validates before making a request', (
    tester,
  ) async {
    await launchApp(tester);

    await tester.tap(find.text('Messages').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'nonsense',
    );
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });
}

/// Discovery answers with one fixed page.
class _ScriptedDiscovery extends DiscoveryRepository {
  _ScriptedDiscovery() : super(ApiClient(sessionStore: SessionStore()));

  static final _page = ProfilePage.fromJson(<String, dynamic>{
    'profiles': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'u1',
        'username': 'zainab',
        'displayName': 'Zainab',
        'age': 26,
        'verificationStatus': 'VERIFIED',
        'datingProfile': <String, dynamic>{
          'city': 'Lagos',
          'country': 'Nigeria',
          'tagline': 'Jollof and jazz',
        },
      },
    ],
    'scope': <String, dynamic>{
      'countryCode': 'NG',
      'countryName': 'Nigeria',
      'pinned': false,
    },
    'pagination': <String, dynamic>{
      'total': 1,
      'page': 1,
      'limit': 12,
      'totalPages': 1,
    },
  });

  @override
  Future<ProfilePage> browse({
    DiscoveryFilters filters = DiscoveryFilters.none,
    int page = 1,
    int limit = 12,
  }) async => _page;

  @override
  Future<ProfilePage> ladies({
    DiscoveryFilters filters = DiscoveryFilters.none,
    int page = 1,
    int limit = 24,
  }) async => _page;

  @override
  Future<Spotlight> spotlight({String? countryCode}) async => Spotlight.empty;

  @override
  Future<List<LocationCount>> locations() async => const <LocationCount>[
    LocationCount(city: 'Lagos', count: 1),
  ];
}

class _ScriptedProfiles extends ProfileRepository {
  _ScriptedProfiles() : super(ApiClient(sessionStore: SessionStore()));

  @override
  Future<ProfileSummary?> publicProfile(String username) async =>
      _ScriptedDiscovery._page.profiles.first;
}
