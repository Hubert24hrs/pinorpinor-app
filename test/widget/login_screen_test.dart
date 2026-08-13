import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/features/auth/login_screen.dart';
import 'package:pinorpinor_app/shared/widgets/brand.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

/// Sign-in is the app's only credential entry point, so its validation and its
/// failure messaging are worth asserting directly.
void main() {
  Future<void> pumpLogin(
    WidgetTester tester,
    FakeAuthRepository repository, {
    Size? size,
  }) async {
    await tester.pumpRouted(
      const LoginScreen(),
      overrides: fakeAuthOverrides(repository),
      surfaceSize: size,
      stubRoutes: const <String>['/home', '/join', '/forgot-password'],
    );
  }

  testWidgets('renders the sign-in form', (tester) async {
    await pumpLogin(tester, FakeAuthRepository());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('rejects a malformed email before making a request', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpLogin(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(GradientButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(repository.signInCalls, isEmpty);
  });

  testWidgets('requires a password', (tester) async {
    final repository = FakeAuthRepository();
    await pumpLogin(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'member@example.com',
    );
    await tester.tap(find.widgetWithText(GradientButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repository.signInCalls, isEmpty);
  });

  testWidgets('does not apply the sign-up length rule to an existing password', (
    tester,
  ) async {
    // A member whose account predates the 8-character floor must still be able
    // to sign in; enforcing it here would lock them out of their own account.
    final repository = FakeAuthRepository();
    await pumpLogin(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'member@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'short',
    );
    await tester.tap(find.widgetWithText(GradientButton, 'Sign in'));
    await tester.pump();

    expect(repository.signInCalls, hasLength(1));
  });

  testWidgets('lowercases the email before sending it', (tester) async {
    // The backend folds emails to lowercase on write; the client matching that
    // is what stops "User@x.com" failing to sign in as "user@x.com".
    final repository = FakeAuthRepository();
    await pumpLogin(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      '  Member@Example.COM  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(GradientButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(repository.signInCalls.single.$1, 'member@example.com');
  });

  testWidgets('shows the server message on a rejected credential', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      signInError: const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Incorrect email or password.',
      ),
    );
    await pumpLogin(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'member@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrongpassword',
    );
    await tester.tap(find.widgetWithText(GradientButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('shows an offline message rather than a blank failure', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      signInError: const ApiException(
        kind: ApiErrorKind.network,
        message: "You're offline. Reconnect and try again.",
      ),
    );
    await pumpLogin(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'member@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(GradientButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('offline'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await pumpLogin(tester, FakeAuthRepository());

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('lays out without overflow at 320px', (tester) async {
    await pumpLogin(tester, FakeAuthRepository(), size: TestDevices.smallPhone);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow on an iPad', (tester) async {
    await pumpLogin(tester, FakeAuthRepository(), size: TestDevices.iPadPro);
    expect(tester.takeException(), isNull);
    // The form is width-capped rather than stretched across the tablet.
    final formWidth = tester.getSize(find.byType(Form)).width;
    expect(formWidth, lessThanOrEqualTo(520));
  });
}
