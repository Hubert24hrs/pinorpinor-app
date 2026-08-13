import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/features/auth/join_screen.dart';
import 'package:pinorpinor_app/shared/widgets/brand.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

/// Registration carries the platform's two hardest rules — 18+ and the
/// women-must-supply-a-number requirement — so its gating is tested at the
/// widget level rather than only in the validators.
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

  testWidgets('opens on the identity step', (tester) async {
    await pumpJoin(tester, FakeAuthRepository());

    expect(find.text('First, the basics'), findsOneWidget);
    expect(find.text('Woman'), findsOneWidget);
    expect(find.text('Man'), findsOneWidget);
    expect(find.textContaining('18+ platform'), findsOneWidget);
  });

  testWidgets('cannot continue without a gender and a date of birth', (
    tester,
  ) async {
    await pumpJoin(tester, FakeAuthRepository());

    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    expect(
      tester.widget<GradientButton>(continueButton).onPressed,
      isNull,
      reason: 'the step must not advance before both are chosen',
    );
  });

  testWidgets('explains that a woman profile is public and reviewed', (
    tester,
  ) async {
    await pumpJoin(tester, FakeAuthRepository());

    await tester.tap(find.text('Woman'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('featured for its first 24 hours'),
      findsOneWidget,
    );
    expect(find.textContaining('reviewed by a moderator'), findsOneWidget);
  });

  testWidgets('explains that a man profile stays private', (tester) async {
    await pumpJoin(tester, FakeAuthRepository());

    await tester.tap(find.text('Man'));
    await tester.pumpAndSettle();

    // Men's profiles are created with isPublic: false and never listed. Saying
    // so at sign-up avoids someone joining and wondering why they are invisible.
    expect(find.textContaining('never listed publicly'), findsOneWidget);
  });

  testWidgets('the date picker cannot offer a date under 18 years ago', (
    tester,
  ) async {
    await pumpJoin(tester, FakeAuthRepository(), size: TestDevices.iPadPro);

    await tester.tap(find.text('Woman'));
    await tester.pumpAndSettle();

    final field = find.text('Select your date of birth');
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();

    // The picker's bound is the visible half of the 18+ rule — it is not
    // possible to *choose* an underage date. The server enforces the other
    // half regardless of what reaches it.
    expect(find.byType(DatePickerDialog), findsOneWidget);
    final dialog = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final now = DateTime.now();
    final latestLegal = DateTime(now.year - 18, now.month, now.day);
    expect(dialog.lastDate.isAfter(latestLegal), isFalse);
  });

  testWidgets('a country is preselected, because discovery is scoped by it', (
    tester,
  ) async {
    await pumpJoin(tester, FakeAuthRepository());
    expect(find.text('Nigeria'), findsOneWidget);
    expect(find.textContaining('scoped by country'), findsOneWidget);
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
