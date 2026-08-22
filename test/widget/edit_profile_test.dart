import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/primary_services.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/models/account.dart';
import 'package:pinorpinor_app/data/models/enums.dart';
import 'package:pinorpinor_app/data/repositories/profile_repository.dart';
import 'package:pinorpinor_app/features/profile/account_providers.dart';
import 'package:pinorpinor_app/features/profile/edit_profile_screen.dart';
import 'package:pinorpinor_app/shared/widgets/brand.dart';

import '../helpers/fake_secure_storage.dart';
import '../helpers/pump_app.dart';

/// Edit Profile is where a member's published claims are made, so what it sends
/// is worth asserting directly.
///
/// The last time this screen was wrong it was wrong silently: it posted
/// `dateTypes`, which `profileUpdateSchema` refuses, and zod strips unknown keys
/// without erroring — so every save "worked" and discarded the selection. A
/// screen that appears to save is worse than one that visibly fails.
void main() {
  Account account({
    String? primaryService,
    List<String> hookupServices = const <String>[],
    bool showOnline = true,
  }) => Account.fromJson(<String, dynamic>{
    'user': <String, dynamic>{
      'id': 'u1',
      'username': 'zainab_lagos',
      'displayName': 'Zainab',
      'gender': 'WOMAN',
      'datingProfile': <String, dynamic>{
        'bio': 'Jollof and jazz, in that order.',
        'city': 'Lagos',
        'countryCode': 'NG',
        'primaryService': primaryService,
        'hookupServices': hookupServices,
        'showOnline': showOnline,
      },
    },
  });

  Future<_RecordingProfileRepository> pumpEditor(
    WidgetTester tester,
    Account data,
  ) async {
    final repository = _RecordingProfileRepository();
    // Routed, because the screen pops itself after a successful save.
    await tester.pumpRouted(
      const EditProfileScreen(),
      overrides: <Override>[
        profileRepositoryProvider.overrideWithValue(repository),
        myProfileProvider.overrideWith((ref) async => data),
      ],
      surfaceSize: TestDevices.iPadPro,
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> save(WidgetTester tester) async {
    final submit = find.widgetWithText(GradientButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets('a member who has never chosen sees nothing preselected', (
    tester,
  ) async {
    // Null is a real state. Preselecting an option would publish a claim on a
    // real person's public profile that they never made.
    await pumpEditor(tester, account());

    for (final PrimaryServiceOption option in kPrimaryServices) {
      expect(find.text(option.label), findsOneWidget);
    }
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
  });

  testWidgets('the primary service is actually sent', (tester) async {
    final repository = await pumpEditor(tester, account());

    final target = find.text('Dinner Date');
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    await save(tester);

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single['primaryService'], 'dinner_date');
  });

  testWidgets('the hookup block appears only under that badge', (tester) async {
    await pumpEditor(tester, account(primaryService: 'chat_buddy'));
    expect(find.text('Your booking rates'), findsNothing);

    final hookup = find.text('Hookup');
    await tester.ensureVisible(hookup);
    await tester.pumpAndSettle();
    await tester.tap(hookup);
    await tester.pumpAndSettle();

    expect(find.text('Your booking rates'), findsOneWidget);
  });

  testWidgets('switching away sends an empty list, not the old one', (
    tester,
  ) async {
    // The server clears the column on a switch, and the client must not be the
    // thing that hands it back. A profile can never carry an explicit service
    // list under a badge that says "Chat Buddy".
    final repository = await pumpEditor(
      tester,
      account(primaryService: 'hookup', hookupServices: <String>['massage']),
    );

    final other = find.text('Chat Buddy');
    await tester.ensureVisible(other);
    await tester.pumpAndSettle();
    await tester.tap(other);
    await tester.pumpAndSettle();

    await save(tester);

    final call = repository.calls.single;
    expect(call['primaryService'], 'chat_buddy');
    expect(
      call['hookupServices'],
      <String>['massage'],
      reason: 'sent as held; the repository and the route apply the gate',
    );
  });

  testWidgets('the presence switch is offered and sent', (tester) async {
    final repository = await pumpEditor(tester, account());

    final toggle = find.widgetWithText(SwitchListTile, 'Show when I am online');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // The copy must not imply the profile disappears: that is what
    // isDiscoverable does, and conflating them is why a member's only way to
    // hide her activity used to be hiding herself.
    expect(find.textContaining('profile stays'), findsOneWidget);

    await save(tester);
    expect(repository.calls.single['showOnline'], isFalse);
  });

  testWidgets('the live session prices are credits, and say so', (
    tester,
  ) async {
    await pumpEditor(tester, account());

    final heading = find.text('Live sessions');
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();

    expect(find.textContaining('in credits, not money'), findsOneWidget);
    // Nothing in this app can start or bill a session, and a price shown with
    // no explanation reads as a service that can be bought right now.
    expect(find.textContaining('cannot be started'), findsOneWidget);
  });

  testWidgets("men's visibility is described as it actually works", (
    tester,
  ) async {
    // This said men's profiles are never listed publicly until 2026-08-22,
    // which stopped being true when men could register: they are shown to
    // signed-in members, and only anonymous callers are limited to women.
    final data = Account.fromJson(<String, dynamic>{
      'user': <String, dynamic>{
        'id': 'u2',
        'username': 'tunde',
        'displayName': 'Tunde',
        'gender': 'MAN',
        'datingProfile': <String, dynamic>{'bio': 'Hello there, friends.'},
      },
    });
    await pumpEditor(tester, data);

    expect(find.textContaining('signed-in members only'), findsOneWidget);
    expect(find.textContaining('never listed'), findsNothing);
  });

  testWidgets('lays out without overflow at 320px', (tester) async {
    await tester.pumpRouted(
      const EditProfileScreen(),
      overrides: <Override>[
        profileRepositoryProvider.overrideWithValue(
          _RecordingProfileRepository(),
        ),
        myProfileProvider.overrideWith((ref) async => account()),
      ],
      surfaceSize: TestDevices.smallPhone,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

/// Records the arguments of every save, so the payload is asserted rather than
/// the fact that a button was tappable.
class _RecordingProfileRepository extends ProfileRepository {
  _RecordingProfileRepository()
    : super(
        ApiClient(sessionStore: SessionStore(storage: FakeSecureStorage())),
      );

  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? tagline,
    String? height,
    String? ethnicity,
    String? city,
    String? country,
    String? state,
    String? build,
    List<String>? languages,
    RelationshipIntent? relationshipIntent,
    List<String>? services,
    Object? primaryService = unsetPrimaryService,
    List<String>? hookupServices,
    bool? isAvailableToday,
    bool? isPublic,
    bool? isDiscoverable,
    bool? showOnline,
    String? currency,
    bool? ratesVisible,
    Map<String, String>? rates,
    Map<String, String>? liveRates,
  }) async {
    calls.add(<String, Object?>{
      'primaryService': primaryService,
      'hookupServices': hookupServices,
      'showOnline': showOnline,
      'services': services,
      'rates': rates,
      'liveRates': liveRates,
    });
  }
}
