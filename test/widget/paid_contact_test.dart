import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/credits.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/models/profile.dart';
import 'package:pinorpinor_app/data/repositories/contact_access_repository.dart';
import 'package:pinorpinor_app/features/discovery/discovery_providers.dart';
import 'package:pinorpinor_app/features/auth/auth_controller.dart';
import 'package:pinorpinor_app/features/profile/profile_detail_screen.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_secure_storage.dart';
import '../helpers/pump_app.dart';

/// The contact block on a profile, which now spends money.
///
/// Opening a chat costs the viewer 100 credits **and costs the member being
/// contacted 100**. Two things follow that the app has to get right, and both
/// are about what a member is told rather than what a request returns.
void main() {
  ProfileSummary profile() => ProfileSummary.fromJson(<String, dynamic>{
    'id': 'u1',
    'username': 'zainab',
    'displayName': 'Zainab',
    'datingProfile': <String, dynamic>{'city': 'Lagos'},
  });

  Future<_FakeContactAccess> pumpProfile(
    WidgetTester tester, {
    ContactAccessFailure? refusal,
    bool signedIn = true,
  }) async {
    final _FakeContactAccess access = _FakeContactAccess()..refusal = refusal;
    final FakeAuthRepository auth = FakeAuthRepository();

    await tester.pumpRouted(
      const ProfileDetailScreen(username: 'zainab'),
      overrides: <Override>[
        contactAccessRepositoryProvider.overrideWithValue(access),
        // Overriding the provider rather than the repository: the screen reads
        // the profile through this one entry point, and a fake repository would
        // have to reimplement more of it than the test is about.
        profileByUsernameProvider(
          'zainab',
        ).overrideWith((Ref ref) async => profile()),
        authRepositoryProvider.overrideWithValue(auth),
        if (signedIn)
          authControllerProvider.overrideWith((Ref ref) => _SignedIn(auth)),
      ],
      surfaceSize: TestDevices.iPadPro,
      stubRoutes: const <String>['/login', '/credits'],
    );
    await tester.pumpAndSettle();
    return access;
  }

  testWidgets('the price is on the button, before the tap', (tester) async {
    // A control that spends credits must say what it costs before it is
    // pressed, not after.
    await pumpProfile(tester);
    expect(
      find.textContaining('$kWhatsAppUnlockCredits credits'),
      findsWidgets,
    );
  });

  testWidgets('it says the other member is charged too', (tester) async {
    // The consequence a member cannot work out from anywhere else: their own
    // balance falls by being contacted, and an empty wallet makes them
    // unreachable. Silence here turns a rule into what looks like a bug.
    await pumpProfile(tester);
    expect(find.textContaining('costs Zainab the same'), findsOneWidget);
  });

  testWidgets('a signed-out visitor is asked to sign in, not charged', (
    tester,
  ) async {
    await pumpProfile(tester, signedIn: false);
    expect(find.textContaining('Sign in to open WhatsApp'), findsOneWidget);
  });

  testWidgets('being short offers a top-up, because that is actionable', (
    tester,
  ) async {
    final _FakeContactAccess access = await pumpProfile(tester);
    access.refusal = const ContactAccessFailure(
      reason: ContactAccessRefusal.viewerShort,
      message: 'You need 100 credits to message this member.',
      price: 100,
      balance: 20,
    );

    await tester.tap(find.textContaining('Open WhatsApp'));
    await tester.pumpAndSettle();

    expect(find.text('Not enough credits'), findsOneWidget);
    expect(find.text('Top up credits'), findsOneWidget);
  });

  testWidgets('the other side being short names no balance and blames nobody', (
    tester,
  ) async {
    final _FakeContactAccess access = await pumpProfile(tester);
    access.refusal = const ContactAccessFailure(
      reason: ContactAccessRefusal.targetCannotReceive,
      message: 'This member cannot receive messages at the moment.',
      price: 100,
    );

    await tester.tap(find.textContaining('Open WhatsApp'));
    await tester.pumpAndSettle();

    expect(find.text('Not accepting messages'), findsOneWidget);
    // No top-up button: the viewer's wallet is not the problem and offering
    // them a purchase would be asking for money that fixes nothing.
    expect(find.text('Top up credits'), findsNothing);
    expect(find.textContaining('cannot receive messages'), findsOneWidget);
  });

  testWidgets('nothing on the screen offers to ask permission any more', (
    tester,
  ) async {
    // The consent flow was removed server-side on 2026-08-23. A button that
    // said "Request contact" could only ever have produced a 404.
    await pumpProfile(tester);
    expect(find.textContaining('Request contact'), findsNothing);
    expect(find.textContaining('they decide'), findsNothing);
  });
}

class _FakeContactAccess extends ContactAccessRepository {
  _FakeContactAccess()
    : super(
        ApiClient(sessionStore: SessionStore(storage: FakeSecureStorage())),
      );

  ContactAccessFailure? refusal;
  int opened = 0;

  @override
  Future<Uri> openChat(String username) async {
    final ContactAccessFailure? failure = refusal;
    if (failure != null) throw failure;
    opened++;
    return Uri.parse('https://wa.me/2348012345678');
  }
}

class _SignedIn extends AuthController {
  _SignedIn(super.repository) {
    state = const AuthState(
      phase: AuthPhase.signedIn,
      session: FakeAuthRepository.defaultSession,
    );
  }
}
