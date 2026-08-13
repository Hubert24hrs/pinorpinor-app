import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';

import '../helpers/fake_secure_storage.dart';

/// The session cookie is the app's only credential, so how it is stored, sent
/// and discarded is worth testing directly.
void main() {
  group('SessionStore', () {
    late SessionStore store;

    setUp(() {
      store = SessionStore(storage: FakeSecureStorage());
    });

    test('starts empty', () async {
      expect(await store.readAll(), isEmpty);
      expect(await store.hasSession, isFalse);
      expect(await store.cookieHeader(), isNull);
    });

    test('recognises the production session cookie name', () async {
      await store.writeAll(<String, String>{
        '__Secure-next-auth.session-token': 'jwt-value',
      });
      expect(await store.hasSession, isTrue);
      expect(await store.readSessionToken(), 'jwt-value');
    });

    test('recognises the plain-HTTP development cookie name', () async {
      // Local development over http gets the unprefixed name; both must work
      // or the app cannot be run against a dev backend.
      await store.writeAll(<String, String>{
        'next-auth.session-token': 'dev-jwt',
      });
      expect(await store.hasSession, isTrue);
    });

    test('merge adds and overwrites', () async {
      await store.writeAll(<String, String>{'a': '1'});
      await store.merge(<String, String>{'b': '2', 'a': '9'});
      expect(await store.readAll(), <String, String>{'a': '9', 'b': '2'});
    });

    test('merge with an empty value removes the cookie', () async {
      // That is how the server signals a sign-out.
      await store.writeAll(<String, String>{
        '__Secure-next-auth.session-token': 'jwt',
      });
      await store.merge(<String, String>{
        '__Secure-next-auth.session-token': '',
      });
      expect(await store.hasSession, isFalse);
    });

    test('builds a Cookie header from every stored pair', () async {
      await store.writeAll(<String, String>{'a': '1', 'b': '2'});
      final header = await store.cookieHeader();
      expect(header, contains('a=1'));
      expect(header, contains('b=2'));
      expect(header, contains('; '));
    });

    test('clear removes everything', () async {
      await store.writeAll(<String, String>{'x': 'y'});
      await store.clear();
      expect(await store.readAll(), isEmpty);
      expect(await store.hasSession, isFalse);
    });

    test('a corrupted blob is treated as signed out, not a crash', () async {
      final storage = FakeSecureStorage()
        ..seed('pnp.session.cookies', 'this is not json');
      final corrupted = SessionStore(storage: storage);
      expect(await corrupted.readAll(), isEmpty);
    });
  });

  group('ApiClient cookie handling', () {
    late FakeSecureStorage storage;
    late SessionStore store;

    setUp(() {
      storage = FakeSecureStorage();
      store = SessionStore(storage: storage);
    });

    test('attaches the stored cookie to an outgoing request', () async {
      await store.writeAll(<String, String>{
        '__Secure-next-auth.session-token': 'jwt-value',
      });

      String? sentCookie;
      final dio = Dio();
      final client = ApiClient(sessionStore: store, dio: dio);
      dio.httpClientAdapter = _StubAdapter((options) {
        sentCookie = options.headers['Cookie'] as String?;
        return ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: _jsonHeaders,
        );
      });

      await client.getJson('/api/profile');
      expect(
        sentCookie,
        contains('__Secure-next-auth.session-token=jwt-value'),
      );
    });

    test('harvests Set-Cookie into secure storage', () async {
      final dio = Dio();
      final client = ApiClient(sessionStore: store, dio: dio);
      dio.httpClientAdapter = _StubAdapter(
        (options) => ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: <String, List<String>>{
            ..._jsonHeaders,
            'set-cookie': <String>[
              '__Secure-next-auth.session-token=fresh-jwt; Path=/; HttpOnly; Secure; SameSite=Lax',
            ],
          },
        ),
      );

      await client.getJson('/api/auth/session');
      expect(await store.readSessionToken(), 'fresh-jwt');
    });

    test(
      'a 403 ACCOUNT_SUSPENDED clears the session and reports the reason',
      () async {
        await store.writeAll(<String, String>{
          '__Secure-next-auth.session-token': 'jwt',
        });

        ApiException? reported;
        final dio = Dio();
        final client = ApiClient(
          sessionStore: store,
          dio: dio,
          onSessionInvalidated: (reason) => reported = reason,
        );
        dio.httpClientAdapter = _StubAdapter(
          (options) => ResponseBody.fromString(
            '{"error":"This account has been suspended.","code":"ACCOUNT_SUSPENDED"}',
            403,
            headers: _jsonHeaders,
          ),
        );

        await expectLater(
          client.getJson('/api/profile'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiErrorKind.accountSuspended,
            ),
          ),
        );

        // A suspension must bite immediately: the stored cookie is dropped so the
        // app cannot keep presenting it.
        expect(await store.hasSession, isFalse);
        expect(reported?.kind, ApiErrorKind.accountSuspended);
      },
    );

    test('a 401 clears the session', () async {
      await store.writeAll(<String, String>{
        '__Secure-next-auth.session-token': 'jwt',
      });

      final dio = Dio();
      final client = ApiClient(sessionStore: store, dio: dio);
      dio.httpClientAdapter = _StubAdapter(
        (options) => ResponseBody.fromString(
          '{"error":"Unauthorized"}',
          401,
          headers: _jsonHeaders,
        ),
      );

      await expectLater(
        client.getJson('/api/profile'),
        throwsA(isA<ApiException>()),
      );
      expect(await store.hasSession, isFalse);
    });

    test('an ordinary 404 leaves the session alone', () async {
      await store.writeAll(<String, String>{
        '__Secure-next-auth.session-token': 'jwt',
      });

      final dio = Dio();
      final client = ApiClient(sessionStore: store, dio: dio);
      dio.httpClientAdapter = _StubAdapter(
        (options) => ResponseBody.fromString(
          '{"error":"Profile not found or not available"}',
          404,
          headers: _jsonHeaders,
        ),
      );

      await expectLater(
        client.getJson('/api/public/profiles/nobody'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.notFound,
          ),
        ),
      );
      expect(await store.hasSession, isTrue);
    });
  });

  group('ApiException mapping', () {
    ApiException map(
      int status,
      String body, {
      Map<String, List<String>>? headers,
    }) {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: body.isEmpty ? null : _decode(body),
          headers: Headers.fromMap(headers ?? <String, List<String>>{}),
        ),
      );
      return ApiException.fromDio(error);
    }

    test('prefers the server message, which is already written for members', () {
      final mapped = map(
        400,
        '{"error":"Password must be between 8 and 100 characters.","field":"password"}',
      );
      expect(mapped.kind, ApiErrorKind.validation);
      expect(mapped.message, contains('between 8 and 100'));
      expect(mapped.field, 'password');
    });

    test('carries username suggestions from a 409', () {
      final mapped = map(
        409,
        '{"error":"taken","suggestions":["zainab1","zainab2"]}',
      );
      expect(mapped.kind, ApiErrorKind.conflict);
      expect(mapped.suggestions, <String>['zainab1', 'zainab2']);
    });

    test('maps 402 to payment required', () {
      expect(
        map(402, '{"error":"no credits"}').kind,
        ApiErrorKind.paymentRequired,
      );
    });

    test('maps 503 to unavailable — the disabled payment routes', () {
      expect(
        map(503, '{"error":"Card payments are unavailable."}').kind,
        ApiErrorKind.unavailable,
      );
    });

    test('reads Retry-After from a 429', () {
      final mapped = map(
        429,
        '{"error":"Too many checks."}',
        headers: <String, List<String>>{
          'retry-after': <String>['42'],
        },
      );
      expect(mapped.kind, ApiErrorKind.rateLimited);
      expect(mapped.retryAfter, const Duration(seconds: 42));
      expect(mapped.isRetryable, isTrue);
    });

    test('falls back to safe copy when the body has no message', () {
      final mapped = map(500, '');
      expect(mapped.kind, ApiErrorKind.server);
      expect(mapped.message, isNotEmpty);
    });

    test('a transport failure becomes a network error, not a server error', () {
      final mapped = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(mapped.kind, ApiErrorKind.network);
      expect(mapped.isRetryable, isTrue);
      expect(mapped.endsSession, isFalse);
    });

    test('only 401 and suspension end the session', () {
      expect(map(401, '').endsSession, isTrue);
      expect(map(403, '{"code":"ACCOUNT_SUSPENDED"}').endsSession, isTrue);
      expect(map(403, '{"error":"Forbidden"}').endsSession, isFalse);
      expect(map(500, '').endsSession, isFalse);
    });
  });
}

const _jsonHeaders = <String, List<String>>{
  'content-type': <String>['application/json'],
};

/// Dio decodes the body before the interceptor chain sees it, so the mapping
/// tests build the already-decoded shape directly.
dynamic _decode(String body) => jsonDecode(body);

typedef _Handler = ResponseBody Function(RequestOptions options);

/// Answers every request from a closure, so the client can be exercised without
/// a network or a mocking framework.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._handler);

  final _Handler _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _handler(options);
}
