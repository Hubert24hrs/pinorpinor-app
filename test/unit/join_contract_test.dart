import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/data/models/enums.dart';
import 'package:pinorpinor_app/data/repositories/auth_repository.dart';

import '../helpers/fake_secure_storage.dart';

/// The registration payload, pinned against the real route.
///
/// **This is the test that did not exist twice.** Registration broke on
/// 2026-08-14 when the route was rebuilt to six fields, and again on 2026-08-21
/// when `gender` and `primaryService` became required. Both times the app kept
/// posting the previous shape; both times the analyzer was clean, every test
/// passed, and the APK built and installed. The only symptom was a 400 on every
/// attempt to create an account.
///
/// Two halves, and both are needed:
///
///   1. **What the app sends** — asserted against a recording adapter, so the
///      body on the wire is checked rather than the arguments to a method.
///   2. **What the route requires** — read out of the website's own source, so
///      a new required field fails here on the day it is added rather than on
///      the day someone tries to sign up.
void main() {
  late _RecordingAdapter adapter;
  late AuthRepository repository;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio();
    // The real ApiClient, not a fake: the body being asserted is the one that
    // would go on the wire, headers, encoding and all.
    final client = ApiClient(
      sessionStore: SessionStore(storage: FakeSecureStorage()),
      dio: dio,
    );
    dio.httpClientAdapter = adapter;
    repository = AuthRepository(client);
  });

  Future<void> join({
    String primaryService = 'dinner_date',
    Gender gender = Gender.woman,
    List<String> services = const <String>[],
    List<String> hookupServices = const <String>[],
    Map<String, String> rates = const <String, String>{},
  }) async {
    adapter.enqueueJson(<String, dynamic>{
      'success': true,
      'userId': 'u1',
      'username': 'zainab_lagos',
    });
    await repository.join(
      username: 'Zainab_Lagos',
      password: 'password123',
      phone: ' +2348012345678 ',
      bio: ' Jollof and jazz. ',
      gender: gender,
      primaryService: primaryService,
      isAdult: true,
      services: services,
      hookupServices: hookupServices,
      rates: rates,
    );
  }

  group('what the app sends', () {
    test('carries gender and the primary service', () async {
      await join();

      final body = adapter.lastJsonBody!;
      expect(body['gender'], 'WOMAN');
      expect(body['primaryService'], 'dinner_date');
      expect(body['isAdult'], isTrue);
      expect(body['username'], 'zainab_lagos', reason: 'normalised');
      expect(body['phone'], '+2348012345678', reason: 'trimmed');
      expect(body['bio'], 'Jollof and jazz.');
    });

    test('men can register, and the wire value is the closed one', () async {
      // The route maps this through a server-side table to `role` and
      // `interestedIn`; anything outside it is a 400.
      await join(gender: Gender.man);
      expect(adapter.lastJsonBody!['gender'], 'MAN');
    });

    test('an unrecognised primary service never leaves the device', () async {
      await expectLater(
        repository.join(
          username: 'zainab_lagos',
          password: 'password123',
          phone: '+2348012345678',
          bio: 'Hello.',
          gender: Gender.woman,
          primaryService: 'not_a_service',
          isAdult: true,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.field, 'field', 'primaryService'),
        ),
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'isAdult false is refused before the request, as the route would',
      () async {
        await expectLater(
          repository.join(
            username: 'zainab_lagos',
            password: 'password123',
            phone: '+2348012345678',
            bio: 'Hello.',
            gender: Gender.woman,
            primaryService: 'dinner_date',
            isAdult: false,
          ),
          throwsA(
            isA<ApiException>().having((e) => e.field, 'field', 'isAdult'),
          ),
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test('services are optional now, and an empty list is fine', () async {
      // Registration asks for the one primary service; the 31-entry activity
      // catalogue moved to Edit Profile on 2026-08-21 and the route made this
      // key optional in the same commit.
      await join();
      expect(adapter.lastJsonBody!['services'], isEmpty);
    });
  });

  group('the hookup gate, applied on the way out', () {
    test('the list and the rates are sent under the hookup badge', () async {
      await join(
        primaryService: 'hookup',
        hookupServices: <String>['massage'],
        rates: <String, String>{'rateShortIncall': '50000'},
      );

      final body = adapter.lastJsonBody!;
      expect(body['hookupServices'], <String>['massage']);
      expect((body['rates']! as Map)['rateShortIncall'], '50000');
    });

    test('and dropped under any other badge', () async {
      // The server discards them anyway. The point of doing it here as well is
      // that a form's leftover state never reaches the wire at all.
      await join(
        primaryService: 'chat_buddy',
        hookupServices: <String>['massage'],
        rates: <String, String>{'rateShortIncall': '50000'},
      );

      final body = adapter.lastJsonBody!;
      expect(body['hookupServices'], isEmpty);
      expect(
        body.containsKey('rates'),
        isFalse,
        reason: 'no rates key at all under a non-hookup service',
      );
    });

    test('unknown ids in the list are dropped, not rejected', () async {
      await join(
        primaryService: 'hookup',
        hookupServices: <String>['not_a_real_one', 'massage'],
      );
      expect(adapter.lastJsonBody!['hookupServices'], <String>['massage']);
    });

    test('rates are sent as typed, never converted here', () async {
      // Converting in the client as well as the route is how a rate ends up
      // stored a hundred times out.
      await join(
        primaryService: 'hookup',
        rates: <String, String>{'rateNightIncall': '120000'},
      );
      expect(
        (adapter.lastJsonBody!['rates']! as Map)['rateNightIncall'],
        '120000',
      );
    });
  });

  group('what the route requires', () {
    final route = File('../pinorpinor/src/app/api/member/join/route.ts');

    test('every field the route rejects the request without is sent', () {
      if (!route.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${route.path}; the registration '
          'contract is unverified in this run',
        );
        return;
      }

      final source = route.readAsStringSync();

      // The route answers 400 with a `field` naming what was missing. Every one
      // of those names must be a key this client actually posts.
      final rejected = <String>{
        for (final m in RegExp(
          r'field:\s*"([A-Za-z]+)"\s*\}?,?\s*\n?\s*\{?\s*status:\s*400',
        ).allMatches(source))
          m.group(1)!,
        for (final m in RegExp(r'field:\s*"([A-Za-z]+)"').allMatches(source))
          m.group(1)!,
      };

      expect(
        rejected,
        isNotEmpty,
        reason: 'could not parse the join route; its shape has changed',
      );

      const sent = <String>{
        'username',
        'password',
        'phone',
        'bio',
        'gender',
        'primaryService',
        'services',
        'hookupServices',
        'rates',
        'isAdult',
        'referralCode',
      };

      for (final String field in rejected) {
        expect(
          sent,
          contains(field),
          reason:
              'the join route can reject a request over "$field", and this app '
              'does not send it. That is a 400 on every attempt to register, '
              'with no compile error and no failing build - exactly how '
              'registration broke on 2026-08-14 and again on 2026-08-21.',
        );
      }
    });

    test('the route still destructures nothing this client cannot supply', () {
      if (!route.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }

      final source = route.readAsStringSync();
      final destructured = source
          .split('const {')[1]
          .split('} = body;')
          .first
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      // Read rather than asserted equal: the route may legitimately read a key
      // this client chooses not to send. What must not happen is the reverse -
      // a key it now requires that nothing here knows about - and the test
      // above covers that. This one simply fails loudly if the shape changes so
      // much that the parse stops working.
      expect(destructured, contains('primaryService'));
      expect(destructured, contains('gender'));
      expect(destructured, contains('isAdult'));
    });
  });
}

/// Records what the client actually posted, and answers from a queue.
///
/// A recording adapter rather than a fake repository on purpose: a fake has
/// whatever signature the real one has, so it can never catch a field that is
/// missing from the payload. Only the encoded body can.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<String> _responses = <String>[];

  void enqueueJson(Map<String, dynamic> body) =>
      _responses.add(jsonEncode(body));

  /// The decoded body of the last request, or null if there was none.
  Map<String, dynamic>? get lastJsonBody {
    if (requests.isEmpty) return null;
    final Object? data = requests.last.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return null;
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      _responses.isEmpty ? '{}' : _responses.removeAt(0),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}
