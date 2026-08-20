import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/services.dart';
import 'package:pinorpinor_app/features/auth/join_screen.dart';
import 'package:pinorpinor_app/shared/widgets/brand.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

/// Registration carries the platform's hardest rules, so its gating is tested
/// at the widget level rather than only in the validators.
///
/// The flow was rebuilt on 2026-08-14 to match the backend's six-field
/// contract. Gender, date of birth and country are no longer collected at all —
/// gender is forced server-side, age is a tickbox, and the country is derived
/// from the WhatsApp number. The tests that asserted those steps are gone with
/// them; what replaces them asserts the rules that actually still exist.
void main() {
  Future<void> pumpJoin(
    WidgetTester tester,
    FakeAuthRepository repository, {
    Size? size,
  }) async {
    await tester.pumpRouted(
      const JoinScreen(),
      overrides: fakeAuthOverrides(repository),
      surfaceSize: size,
      stubRoutes: const <String>['/home', '/verify', '/login'],
    );
  }

  // Derived from the catalogue rather than hardcoded. The catalogue is
  // generated from the website and was reworked once mid-development; a test
  // naming a literal label breaks on a rewording that is not a defect.
  final firstService = kServices.firstWhere((s) => !s.retired);

  /// Fills step one and advances to the WhatsApp/bio step.
  Future<void> completeAccountStep(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'zainab_lagos',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'password123',
    );
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    await tester.ensureVisible(continueButton.first);
    await tester.pumpAndSettle();
    await tester.tap(continueButton.first);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the username step', (tester) async {
    await pumpJoin(tester, FakeAuthRepository());

    expect(find.text('Choose your name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
  });

  testWidgets('warns that a forgotten password cannot be recovered', (
    tester,
  ) async {
    // The single most consequential thing about the new flow: no email is
    // collected, so /api/forgot-password has nothing to look a member up by.
    // Saying so after the account exists would be saying so too late.
    await pumpJoin(tester, FakeAuthRepository());

    expect(find.textContaining('no way to reset a forgotten password'),
        findsOneWidget);
  });

  testWidgets('will not advance past an invalid username', (tester) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'x',
    );
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    await tester.ensureVisible(continueButton.first);
    await tester.pumpAndSettle();
    await tester.tap(continueButton.first);
    await tester.pumpAndSettle();

    expect(find.text('Choose your name'), findsOneWidget);
    expect(repository.joinCalls, isEmpty);
  });

  testWidgets('requires the two passwords to match', (tester) async {
    await pumpJoin(tester, FakeAuthRepository());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'zainab_lagos',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'password124',
    );
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    await tester.ensureVisible(continueButton.first);
    await tester.pumpAndSettle();
    await tester.tap(continueButton.first);
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('explains that the number places the member in discovery', (
    tester,
  ) async {
    await pumpJoin(tester, FakeAuthRepository());
    await completeAccountStep(tester);

    expect(find.text('How members reach you'), findsOneWidget);
    // Not decoration: discovery scopes on the country resolved from this
    // number, so a member whose number does not resolve is listed nowhere.
    expect(find.textContaining('place you in local discovery'), findsOneWidget);
    expect(find.textContaining('never shown to other members'), findsOneWidget);
  });

  testWidgets('rejects a number that is not in international format', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository);
    await completeAccountStep(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      '08012345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'About you'),
      'Hello there.',
    );
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    await tester.ensureVisible(continueButton.first);
    await tester.pumpAndSettle();
    await tester.tap(continueButton.first);
    await tester.pumpAndSettle();

    // Still on the same step, and nothing has been sent.
    expect(find.text('How members reach you'), findsOneWidget);
    expect(repository.joinCalls, isEmpty);
  });

  testWidgets('the submit button stays disabled until 18+ is confirmed', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository, size: TestDevices.iPadPro);
    await completeAccountStep(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      '+2348012345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'About you'),
      'Hello there.',
    );
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    await tester.ensureVisible(continueButton.first);
    await tester.pumpAndSettle();
    await tester.tap(continueButton.first);
    await tester.pumpAndSettle();

    expect(find.text('What you offer'), findsOneWidget);

    final submit = find.widgetWithText(GradientButton, 'Create my account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    // Neither a service nor the tickbox yet.
    expect(
      tester.widget<GradientButton>(submit).onPressed,
      isNull,
      reason: 'the backend rejects isAdult != true outright',
    );

    // Selecting a service alone is still not enough.
    final chip = find.widgetWithText(FilterChip, firstService.label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(submit).onPressed, isNull);

    expect(repository.joinCalls, isEmpty);
  });

  testWidgets('sends the six fields the backend actually reads', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository, size: TestDevices.iPadPro);
    await completeAccountStep(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      '+2348012345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'About you'),
      'Jollof and jazz.',
    );
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    await tester.ensureVisible(continueButton.first);
    await tester.pumpAndSettle();
    await tester.tap(continueButton.first);
    await tester.pumpAndSettle();

    final chip = find.widgetWithText(FilterChip, firstService.label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    final tickbox = find.byType(CheckboxListTile);
    await tester.ensureVisible(tickbox);
    await tester.pumpAndSettle();
    await tester.tap(tickbox);
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(GradientButton, 'Create my account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.joinCalls, hasLength(1));
    final call = repository.joinCalls.single;
    expect(call['username'], 'zainab_lagos');
    expect(call['phone'], '+2348012345678');
    expect(call['bio'], 'Jollof and jazz.');
    expect(call['services'], <String>[firstService.id]);
    expect(call['isAdult'], isTrue);
  });

  testWidgets('never calls join before every step is satisfied', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository);

    // Nothing has been filled in, so no request may leave the device.
    expect(repository.joinCalls, isEmpty);
  });

  testWidgets('lays out without overflow at 320px', (tester) async {
    await pumpJoin(tester, FakeAuthRepository(), size: TestDevices.smallPhone);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow on a tablet', (tester) async {
    await pumpJoin(tester, FakeAuthRepository(), size: TestDevices.tablet);
    expect(tester.takeException(), isNull);
  });
}
