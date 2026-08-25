import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/primary_services.dart';
import 'package:pinorpinor_app/core/constants/service_features.dart';
import 'package:pinorpinor_app/features/auth/join_screen.dart';
import 'package:pinorpinor_app/shared/widgets/brand.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

/// Registration carries the platform's hardest rules, so its gating is tested
/// at the widget level rather than only in the validators.
///
/// The flow was rebuilt on 2026-08-14 and again on 2026-08-21, and both
/// rebuilds broke registration outright without breaking a single test, a build
/// or a type. What is asserted here is the current contract:
///
///   * date of birth and country are still not collected — age is a tickbox and
///     the country is derived from the WhatsApp number;
///   * **gender is collected again**, and the route 400s without it;
///   * **one primary service is required**, and the route 400s without that too;
///   * the hookup branch only exists under one of the six choices, and nothing
///     it holds may be sent under any other.
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

  // Derived from the catalogue rather than hardcoded. It is generated from the
  // website and has been reworked twice; a test naming a literal label breaks on
  // a rewording that is not a defect.
  final PrimaryServiceOption nonHookup = kPrimaryServices.firstWhere(
    (s) => s.id != kHookupId,
  );
  final PrimaryServiceOption hookup = kPrimaryServices.firstWhere(
    (s) => s.id == kHookupId,
  );

  /// Fills the WhatsApp/bio step and advances to the service step.
  Future<void> completeDetailsStep(
    WidgetTester tester, {
    String bio = 'Hello there.',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      '+2348012345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'About you'),
      bio,
    );
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    await tester.ensureVisible(continueButton.first);
    await tester.pumpAndSettle();
    await tester.tap(continueButton.first);
    await tester.pumpAndSettle();
  }

  /// A year that is comfortably an adult whenever this runs. Derived rather
  /// than hardcoded, so the test does not expire.
  final String adultYear = '${DateTime.now().year - 30}';

  /// Fills the year of birth, which the route rejects the request without.
  Future<void> enterYear(WidgetTester tester) async {
    final field = find.widgetWithText(TextFormField, 'Year of birth');
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, adultYear);
    await tester.pumpAndSettle();
  }

  /// Taps one of the six primary-service cards by its label.
  Future<void> choose(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

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

  testWidgets('tells the truth about recovering a forgotten password', (
    tester,
  ) async {
    // This screen used to warn that a forgotten password could never be reset.
    // That was true when registration stopped collecting email addresses, and
    // stopped being true on 2026-08-22 when WhatsApp recovery shipped.
    // Frightening somebody off a form with an outdated warning costs signups
    // for nothing, so the old claim must not come back.
    await pumpJoin(tester, FakeAuthRepository());

    expect(
      find.textContaining('no way to reset a forgotten password'),
      findsNothing,
    );
    expect(
      find.textContaining('reset your password with a code'),
      findsOneWidget,
    );
  });

  testWidgets('will not advance past an invalid username', (tester) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository);

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'x');
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

  testWidgets('the submit button stays disabled until every answer is given', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository, size: TestDevices.iPadPro);
    await completeAccountStep(tester);
    await completeDetailsStep(tester);

    expect(find.text('What you are here for'), findsOneWidget);

    final submit = find.widgetWithText(GradientButton, 'Create my account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    // Nothing answered yet.
    expect(
      tester.widget<GradientButton>(submit).onPressed,
      isNull,
      reason: 'the route rejects a missing gender, service or isAdult',
    );

    // Gender alone is not enough: the route 400s without a primary service.
    await choose(tester, 'A woman');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(submit).onPressed, isNull);

    // Gender and service, still without the tickbox.
    await choose(tester, nonHookup.label);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(
      tester.widget<GradientButton>(submit).onPressed,
      isNull,
      reason: 'the backend rejects isAdult != true outright',
    );

    expect(repository.joinCalls, isEmpty);
  });

  testWidgets('sends gender and the primary service, which the route demands', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository, size: TestDevices.iPadPro);
    await completeAccountStep(tester);
    await completeDetailsStep(tester, bio: 'Jollof and jazz.');

    await enterYear(tester);
    await choose(tester, 'A woman');
    await choose(tester, nonHookup.label);

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
    expect(call['gender'], 'WOMAN');
    expect(call['primaryService'], nonHookup.id);
    expect(call['birthYear'], adultYear);
    expect(call['isAdult'], isTrue);
  });

  testWidgets('booking rates appear only under hookup', (tester) async {
    // The rates stayed Hookup-only when the feature list was generalised on
    // 2026-08-22: the other five services do not describe a meeting that is
    // charged for.
    await pumpJoin(tester, FakeAuthRepository(), size: TestDevices.iPadPro);
    await completeAccountStep(tester);
    await completeDetailsStep(tester);

    await choose(tester, 'A woman');
    await choose(tester, nonHookup.label);
    expect(find.text('Your booking rates'), findsNothing);

    await choose(tester, hookup.label);
    expect(find.text('Your booking rates'), findsOneWidget);
  });

  testWidgets('every service offers a feature list, not just hookup', (
    tester,
  ) async {
    // The asymmetry this removed: a Relationship profile used to be a bare
    // badge while a Hookup profile carried thirty specifics, which made the
    // explicit list look like the point of the platform.
    await pumpJoin(tester, FakeAuthRepository(), size: TestDevices.iPadPro);
    await completeAccountStep(tester);
    await completeDetailsStep(tester);
    await choose(tester, 'A woman');

    for (final PrimaryServiceOption option in kPrimaryServices) {
      await choose(tester, option.label);
      expect(
        find.text(featuresHeading(option.id)),
        findsOneWidget,
        reason: '${option.label} has no feature list',
      );
    }
  });

  testWidgets('the explicit list warns that it is public', (tester) async {
    await pumpJoin(tester, FakeAuthRepository(), size: TestDevices.iPadPro);
    await completeAccountStep(tester);
    await completeDetailsStep(tester);
    await choose(tester, 'A woman');

    await choose(tester, nonHookup.label);
    expect(find.textContaining('This list is explicit'), findsNothing);

    await choose(tester, hookup.label);
    expect(find.textContaining('This list is explicit'), findsOneWidget);
  });

  testWidgets('switching service discards what the old catalogue collected', (
    tester,
  ) async {
    // Not cosmetic. Feature ids are prefixed per catalogue, so a selection kept
    // across a switch is a selection the server will drop — and a form that
    // keeps hidden answers is a form that eventually submits one.
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository, size: TestDevices.iPadPro);
    await completeAccountStep(tester);
    await completeDetailsStep(tester);

    await enterYear(tester);
    await choose(tester, 'A woman');
    await choose(tester, hookup.label);

    final chip = find.byType(FilterChip).first;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    await choose(tester, nonHookup.label);

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

    final call = repository.joinCalls.single;
    expect(call['primaryService'], nonHookup.id);
    expect(call['serviceFeatures'], isEmpty);
    expect(call['rates'], isEmpty);
  });

  testWidgets('the year of birth gates the submit button', (tester) async {
    // Registration had no server-side age bound at all between 2026-08-14 and
    // 2026-08-21 — the tickbox was the only thing between a minor and an
    // account. This is a declaration with a bound, never verification.
    final repository = FakeAuthRepository();
    await pumpJoin(tester, repository, size: TestDevices.iPadPro);
    await completeAccountStep(tester);
    await completeDetailsStep(tester);

    await choose(tester, 'A woman');
    await choose(tester, nonHookup.label);

    final tickbox = find.byType(CheckboxListTile);
    await tester.ensureVisible(tickbox);
    await tester.pumpAndSettle();
    await tester.tap(tickbox);
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(GradientButton, 'Create my account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(
      tester.widget<GradientButton>(submit).onPressed,
      isNull,
      reason: 'no year yet, and the route 400s without one',
    );

    // A year that makes them 10 is refused, not merely unhelpful.
    final field = find.widgetWithText(TextFormField, 'Year of birth');
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '${DateTime.now().year - 10}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(submit).onPressed, isNull);

    await enterYear(tester);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(submit).onPressed, isNotNull);
    expect(repository.joinCalls, isEmpty);
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
