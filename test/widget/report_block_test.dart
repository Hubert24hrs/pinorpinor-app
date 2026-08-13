import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/repositories/safety_repository.dart';
import 'package:pinorpinor_app/features/auth/auth_controller.dart';
import 'package:pinorpinor_app/features/moderation/report_block_sheet.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_secure_storage.dart';
import '../helpers/pump_app.dart';

/// Reporting and blocking are the safety controls both app stores require of a
/// user-generated-content app, so their reachability is tested rather than
/// assumed.
class _FakeSafetyRepository extends SafetyRepository {
  _FakeSafetyRepository()
    : super(
        ApiClient(sessionStore: SessionStore(storage: FakeSecureStorage())),
      );

  final List<(String, ReportReason, String?)> reports =
      <(String, ReportReason, String?)>[];
  final List<String> blocks = <String>[];
  final List<String> unblocks = <String>[];

  @override
  Future<void> report({
    required String reportedUserId,
    required ReportReason reason,
    String? details,
  }) async {
    reports.add((reportedUserId, reason, details));
  }

  @override
  Future<void> block(String blockedUserId) async => blocks.add(blockedUserId);

  @override
  Future<void> unblock(String blockedUserId) async =>
      unblocks.add(blockedUserId);
}

void main() {
  late _FakeSafetyRepository safety;
  late FakeAuthRepository auth;

  setUp(() {
    safety = _FakeSafetyRepository();
    auth = FakeAuthRepository();
  });

  /// A host with a button that opens the sheet, plus a signed-in session.
  Future<void> pumpHost(WidgetTester tester, {bool signedIn = true}) async {
    await tester.pumpRouted(
      const _SheetHost(userId: 'target-user', displayName: 'Zainab'),
      overrides: <Override>[
        ...fakeAuthOverrides(auth),
        safetyRepositoryProvider.overrideWithValue(safety),
      ],
      stubRoutes: const <String>['/login'],
    );

    if (signedIn) {
      // Drive the controller into a signed-in state the way the app does.
      final element = tester.element(find.byType(_SheetHost));
      final container = ProviderScope.containerOf(element, listen: false);
      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'member@example.com', password: 'password123');
      await tester.pump();
    }
  }

  testWidgets('offers both report and block', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Report this profile'), findsOneWidget);
    expect(find.text('Block Zainab'), findsOneWidget);
  });

  testWidgets('blocking asks for confirmation and explains the consequence', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Zainab'));
    await tester.pumpAndSettle();

    expect(find.text('Block Zainab?'), findsOneWidget);
    // A block also ends any existing match, server-side, in the same
    // transaction. The dialog must say so before it happens.
    expect(find.textContaining('existing match is ended'), findsOneWidget);
    expect(safety.blocks, isEmpty);
  });

  testWidgets('confirming sends the block', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Zainab'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    expect(safety.blocks, <String>['target-user']);
  });

  testWidgets('cancelling does not block', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Zainab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(safety.blocks, isEmpty);
  });

  testWidgets('the report form requires a reason before it can be submitted', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report this profile'));
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Submit report');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(safety.reports, isEmpty);
  });

  testWidgets('submits the chosen reason', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report this profile'));
    await tester.pumpAndSettle();

    // The sheet scrolls: seven reasons plus a details field do not fit a
    // 600px-tall test surface, so each target is brought into view first.
    final reason = find.text(ReportReason.underage.label);
    await tester.ensureVisible(reason);
    await tester.pumpAndSettle();
    await tester.tap(reason);
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Submit report');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(safety.reports, hasLength(1));
    expect(safety.reports.single.$1, 'target-user');
    expect(safety.reports.single.$2, ReportReason.underage);
  });

  testWidgets('offers every documented reason', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report this profile'));
    await tester.pumpAndSettle();

    for (final reason in ReportReason.values) {
      expect(
        find.text(reason.label),
        findsOneWidget,
        reason: '${reason.name} must be offered',
      );
    }
  });

  testWidgets('a signed-out visitor is asked to sign in rather than failing', (
    tester,
  ) async {
    await pumpHost(tester, signedIn: false);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Zainab'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to report or block members.'), findsOneWidget);
    expect(safety.blocks, isEmpty);
  });
}

class _SheetHost extends ConsumerWidget {
  const _SheetHost({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showReportBlockSheet(
            context: context,
            ref: ref,
            userId: userId,
            displayName: displayName,
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}
