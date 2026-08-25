import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/credits.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/data/repositories/contact_access_repository.dart';

import '../helpers/fake_secure_storage.dart';

/// Opening a paid WhatsApp chat, and the two refusals that are not the same
/// thing.
///
/// Since 2026-08-23 the sender pays 100 credits and the member being contacted
/// pays 100, in one transaction. If either wallet is short, neither is charged.
/// The app has to render those two failures differently, and one of them has a
/// hard privacy rule attached.
void main() {
  late _Adapter adapter;
  late ContactAccessRepository repository;

  setUp(() {
    adapter = _Adapter();
    final Dio dio = Dio();
    final ApiClient client = ApiClient(
      sessionStore: SessionStore(storage: FakeSecureStorage()),
      dio: dio,
    );
    dio.httpClientAdapter = adapter;
    repository = ContactAccessRepository(client);
  });

  test('the price is the one the server charges', () {
    expect(repository.price, kWhatsAppUnlockCredits);
    expect(kWhatsAppUnlockCredits, 100);
  });

  test(
    'a successful unlock returns the wa.me link from the redirect',
    () async {
      adapter.redirectTo = 'https://wa.me/2348012345678?text=Hello';
      final Uri link = await repository.openChat('Zainab');
      expect(link.host, 'wa.me');
      expect(link.queryParameters['text'], 'Hello');
    },
  );

  test('the app scheme keeps the number and the prefilled text', () {
    final Uri app = ContactAccessRepository.toAppScheme(
      Uri.parse('https://wa.me/2348012345678?text=Hi%20there'),
    );
    expect(app.scheme, 'whatsapp');
    expect(app.queryParameters['phone'], '2348012345678');
    expect(app.queryParameters['text'], 'Hi there');
  });

  group('when the viewer is short', () {
    setUp(() {
      adapter.failure = (
        status: 402,
        body: <String, dynamic>{
          'error': 'You need 100 credits to message this member.',
          'code': 'INSUFFICIENT_CREDITS',
          'price': 100,
          'balance': 40,
        },
      );
    });

    test('it is a state the screen can act on, not a generic error', () async {
      final Object error = await repository
          .openChat('zainab')
          .then<Object>((_) => 'no error', onError: (Object e) => e);

      expect(error, isA<ContactAccessFailure>());
      final ContactAccessFailure failure = error as ContactAccessFailure;
      expect(failure.reason, ContactAccessRefusal.viewerShort);
      expect(failure.price, 100);
      expect(failure.balance, 40);
      expect(failure.shortfall, 60);
    });
  });

  group('when the other member cannot receive', () {
    setUp(() {
      adapter.failure = (
        status: 409,
        body: <String, dynamic>{
          'error': 'This member cannot receive messages at the moment.',
          'code': 'TARGET_CANNOT_RECEIVE',
        },
      );
    });

    test(
      'no balance is carried, because it is not the viewer\'s business',
      () async {
        final Object error = await repository
            .openChat('zainab')
            .then<Object>((_) => 'no error', onError: (Object e) => e);

        final ContactAccessFailure failure = error as ContactAccessFailure;
        expect(failure.reason, ContactAccessRefusal.targetCannotReceive);
        expect(
          failure.balance,
          isNull,
          reason:
              'the other member\'s wallet must never reach this client, and a '
              'shortfall would let it be inferred',
        );
        expect(failure.shortfall, isNull);
      },
    );

    test('the message blames nobody and names no figure', () async {
      final Object error = await repository
          .openChat('zainab')
          .then<Object>((_) => 'no error', onError: (Object e) => e);

      final String message = (error as ContactAccessFailure).message;
      // The server's own wording. The viewer did nothing wrong and is owed an
      // explanation rather than an accusation.
      expect(message, contains('cannot receive messages'));
      expect(message, isNot(contains('credits')));
      expect(message, isNot(contains('balance')));
    });
  });

  test('404 stays a plain not-found, and is not interpreted further', () async {
    // The backend uses one 404 for "no such profile", "hidden", "opted out" and
    // "no number on file" alike, so a caller cannot probe which profiles have a
    // reachable number. Splitting them here would undo that.
    adapter.failure = (
      status: 404,
      body: <String, dynamic>{
        'error': 'This member is not reachable on WhatsApp.',
      },
    );

    final Object error = await repository
        .openChat('zainab')
        .then<Object>((_) => 'no error', onError: (Object e) => e);

    expect(error, isA<ApiException>());
    expect(error, isNot(isA<ContactAccessFailure>()));
    expect((error as ApiException).kind, ApiErrorKind.notFound);
  });

  test(
    'a signed-out caller is told to sign in, not sent to a login page',
    () async {
      adapter.redirectTo = 'https://pinorpinor.com/login?callbackUrl=%2F';
      final Object error = await repository
          .openChat('zainab')
          .then<Object>((_) => 'no error', onError: (Object e) => e);

      expect((error as ApiException).kind, ApiErrorKind.unauthorized);
    },
  );
}

/// Answers the unlock request with a redirect or a refusal.
class _Adapter implements HttpClientAdapter {
  String redirectTo = 'https://wa.me/2348012345678';
  ({int status, Map<String, dynamic> body})? failure;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ({int status, Map<String, dynamic> body})? refusal = failure;
    if (refusal != null) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: refusal.status,
          data: refusal.body,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    return ResponseBody.fromString(
      '',
      307,
      headers: <String, List<String>>{
        'location': <String>[redirectTo],
      },
    );
  }
}
