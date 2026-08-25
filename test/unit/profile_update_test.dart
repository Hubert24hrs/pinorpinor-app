import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/data/repositories/profile_repository.dart';

import '../helpers/fake_secure_storage.dart';

/// What a profile save actually puts on the wire.
///
/// This screen has now written two columns the schema refuses — `dateTypes`, and
/// then `relationshipIntent` after the website dropped it — and both times zod
/// stripped the key silently, so every save "worked" and discarded the answer. A
/// recording adapter is the only thing that catches that: a fake repository has
/// whatever signature the real one has.
void main() {
  late _Recorder adapter;
  late ProfileRepository repository;

  setUp(() {
    adapter = _Recorder();
    final Dio dio = Dio();
    final ApiClient client = ApiClient(
      sessionStore: SessionStore(storage: FakeSecureStorage()),
      dio: dio,
    );
    dio.httpClientAdapter = adapter;
    repository = ProfileRepository(client);
  });

  group('the primary service sentinel', () {
    test('absent means the key is not sent at all', () async {
      await repository.updateProfile(bio: 'Hello there, friends.');
      expect(
        adapter.lastBody!.containsKey('primaryService'),
        isFalse,
        reason: '"leave it alone" must not be sent as a value',
      );
    });

    test('an explicit null clears the badge', () async {
      // Without this there is no way to withdraw a claim once published.
      await repository.updateProfile(primaryService: null);
      expect(adapter.lastBody!.containsKey('primaryService'), isTrue);
      expect(adapter.lastBody!['primaryService'], isNull);
    });

    test('features are gated against the service being set', () async {
      await repository.updateProfile(
        primaryService: 'relationship',
        serviceFeatures: <String>['massage', 'rel_long_term'],
      );
      expect(adapter.lastBody!['serviceFeatures'], <String>[
        'rel_long_term',
      ], reason: 'a Hookup id must not survive a save that sets Relationship');
    });

    test(
      'clearing the badge stores no features, because no catalogue applies',
      () async {
        // The bug this pins: "absent" and "explicit null" both leave the effective
        // service null, and treating the second as the first would post a stale
        // list against a profile that has no catalogue at all.
        await repository.updateProfile(
          primaryService: null,
          serviceFeatures: <String>['rel_long_term'],
        );
        expect(adapter.lastBody!['serviceFeatures'], isEmpty);
      },
    );

    test(
      'a features-only save sends them as held, for the server to gate',
      () async {
        // The stored service still governs, and this client cannot see it.
        // Dropping them here would clear the very list the member came to edit.
        await repository.updateProfile(
          serviceFeatures: <String>['rel_long_term'],
        );
        expect(adapter.lastBody!['serviceFeatures'], <String>['rel_long_term']);
      },
    );
  });

  group('columns the schema refuses are never sent', () {
    test('relationshipIntent is gone, not merely unused', () async {
      // Removed from profileUpdateSchema on 2026-08-25. Zod strips unknown keys
      // without erroring, so sending it would be an editor for a field that
      // cannot be saved -- exactly the dateTypes bug, a second time.
      await repository.updateProfile(
        bio: 'Hello there.',
        primaryService: 'relationship',
        serviceFeatures: <String>['rel_long_term'],
        birthYear: '1998',
      );
      expect(adapter.lastBody!.containsKey('relationshipIntent'), isFalse);
      expect(adapter.lastBody!.containsKey('dateTypes'), isFalse);
      expect(adapter.lastBody!.containsKey('hookupServices'), isFalse);
    });
  });

  group('the birth year', () {
    test('is sent as typed, and an empty one clears it', () async {
      await repository.updateProfile(birthYear: '1998');
      expect(adapter.lastBody!['birthYear'], '1998');

      await repository.updateProfile(birthYear: '');
      expect(adapter.lastBody!.containsKey('birthYear'), isTrue);
      expect(adapter.lastBody!['birthYear'], isNull);
    });
  });
}

class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  Map<String, dynamic>? get lastBody {
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
      '{"success":true}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}
