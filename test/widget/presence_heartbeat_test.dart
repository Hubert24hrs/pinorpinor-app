import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/repositories/presence_repository.dart';
import 'package:pinorpinor_app/features/auth/auth_controller.dart';
import 'package:pinorpinor_app/features/presence/presence_heartbeat.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_secure_storage.dart';
import '../helpers/pump_app.dart';

/// The heartbeat, which is the whole of the app's contribution to "who is
/// online".
///
/// `users.lastSeenAt` is written inside the backend's `requireAuth()`, and
/// almost nothing a member does hits an authenticated endpoint — browsing,
/// discovery and every public profile are unauthenticated reads. Without this
/// timer a signed-in member using the app is invisible on the live surfaces of
/// **both** clients, because both read the same column. The bug is invisible
/// too: presence never lies, it just under-reports, and an empty "who is
/// online" reads as a quiet night rather than a defect. So the behaviour is
/// pinned here rather than left to be noticed.
void main() {
  late _FakePresenceRepository presence;

  setUp(() => presence = _FakePresenceRepository());

  Future<void> pump(WidgetTester tester, {required bool signedIn}) async {
    final repository = FakeAuthRepository();
    await tester.pumpApp(
      const PresenceHeartbeat(child: SizedBox.shrink()),
      overrides: <Override>[
        presenceRepositoryProvider.overrideWithValue(presence),
        authRepositoryProvider.overrideWithValue(repository),
        if (signedIn)
          authControllerProvider.overrideWith(
            (ref) => _SignedInController(repository),
          ),
      ],
    );
  }

  testWidgets('a signed-out visitor never beats', (tester) async {
    await pump(tester, signedIn: false);
    await tester.pump(const Duration(minutes: 10));

    // There is no such thing as an anonymous member being online, and the route
    // would answer 401 anyway.
    expect(presence.beats, 0);
  });

  testWidgets('a signed-in member beats immediately', (tester) async {
    await pump(tester, signedIn: true);
    await tester.pump();

    expect(
      presence.beats,
      greaterThanOrEqualTo(1),
      reason: 'someone who has just opened the app is exactly who this reports',
    );
  });

  testWidgets('and keeps beating on the server\'s own interval', (
    tester,
  ) async {
    await pump(tester, signedIn: true);
    await tester.pump();
    final int first = presence.beats;

    await tester.pump(kPresenceInterval);
    expect(presence.beats, first + 1);

    await tester.pump(kPresenceInterval);
    expect(presence.beats, first + 2);

    // Leave no timer pending, or the test framework fails the teardown.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the interval matches the server-side throttle', (tester) async {
    // Faster spends requests the server drops on the floor; slower lets an
    // active member fall out of the five-minute online window while she is
    // using the app. PRESENCE_WRITE_INTERVAL_MS on the website is two minutes.
    expect(kPresenceInterval, const Duration(minutes: 2));
  });

  testWidgets('a failure is swallowed and the next beat still runs', (
    tester,
  ) async {
    presence.failNext = true;
    await pump(tester, signedIn: true);
    await tester.pump();

    // No exception reached the framework: a member must never see an error
    // about a heartbeat.
    expect(tester.takeException(), isNull);

    presence.failNext = false;
    await tester.pump(kPresenceInterval);
    expect(presence.beats, greaterThanOrEqualTo(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakePresenceRepository extends PresenceRepository {
  _FakePresenceRepository()
    : super(
        ApiClient(sessionStore: SessionStore(storage: FakeSecureStorage())),
      );

  int beats = 0;
  bool failNext = false;

  @override
  Future<void> beat() async {
    beats++;
    if (failNext) {
      throw const ApiException(kind: ApiErrorKind.network, message: 'offline');
    }
  }
}

/// An [AuthController] that is already signed in, without a round trip.
class _SignedInController extends AuthController {
  _SignedInController(super.repository) {
    state = const AuthState(
      phase: AuthPhase.signedIn,
      session: FakeAuthRepository.defaultSession,
    );
  }
}
