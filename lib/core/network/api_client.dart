import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../utils/app_log.dart';
import 'api_exception.dart';
import 'session_store.dart';

/// Signalled when the backend rejects the stored session, so the app can drop
/// it and route to sign-in from one place rather than at every call site.
typedef SessionInvalidated = void Function(ApiException reason);

/// The single HTTP entry point to the Pinorpinor backend.
///
/// It talks to the same Next.js API the website uses, which means it also has
/// to speak NextAuth's cookie session. Dio's own cookie manager writes to disk
/// in the clear, so cookies are attached and harvested here by hand and stored
/// through [SessionStore] (Keystore / Keychain) instead.
class ApiClient {
  ApiClient({
    required SessionStore sessionStore,
    Dio? dio,
    this.onSessionInvalidated,
  }) : // An initializing formal is not possible here: the field is private, and
       // Dart forbids a private named parameter.
       // ignore: prefer_initializing_formals
       _sessionStore = sessionStore,
       _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: AppConfig.apiOrigin,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.receiveTimeout,
      responseType: ResponseType.json,
      // Redirects are followed manually where a route uses one as its result
      // (the WhatsApp handoff), so the default stays on for everything else.
      followRedirects: true,
      headers: <String, String>{
        'Accept': 'application/json',
        // Lets the backend distinguish app traffic in its logs without
        // identifying the individual device.
        'X-Pinorpinor-Client': 'flutter',
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final cookie = await _sessionStore.cookieHeader();
          if (cookie != null) options.headers['Cookie'] = cookie;
          handler.next(options);
        },
        onResponse: (response, handler) async {
          await _absorbCookies(response.headers);
          handler.next(response);
        },
        onError: (error, handler) async {
          final headers = error.response?.headers;
          if (headers != null) await _absorbCookies(headers);
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStore _sessionStore;
  final SessionInvalidated? onSessionInvalidated;

  Dio get raw => _dio;
  SessionStore get sessionStore => _sessionStore;

  /// Pulls `Set-Cookie` off a response into secure storage.
  ///
  /// Only the name/value pair is kept. Attributes (`Path`, `SameSite`, `Max-Age`)
  /// describe browser behaviour that does not apply here — the app sends its
  /// cookies to exactly one origin and clears them on sign-out.
  Future<void> _absorbCookies(Headers headers) async {
    final raw = headers[HttpHeaders.setCookie];
    if (raw == null || raw.isEmpty) return;

    final harvested = <String, String>{};
    for (final entry in raw) {
      final firstPair = entry.split(';').first.trim();
      final separator = firstPair.indexOf('=');
      if (separator <= 0) continue;
      final name = firstPair.substring(0, separator).trim();
      final value = firstPair.substring(separator + 1).trim();
      if (name.isEmpty) continue;
      harvested[name] = value;
    }
    await _sessionStore.merge(harvested);
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => _dio.get<T>(path, queryParameters: query, cancelToken: cancelToken),
  );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,

    /// NextAuth's own routes read a form body rather than JSON, so the content
    /// type has to be selectable per call.
    String? contentType,
  }) => _send<T>(
    () => _dio.post<T>(
      path,
      data: body,
      queryParameters: query,
      cancelToken: cancelToken,
      options: contentType == null ? null : Options(contentType: contentType),
    ),
  );

  /// `application/x-www-form-urlencoded`, for the NextAuth endpoints.
  static const formContentType = Headers.formUrlEncodedContentType;

  Future<T> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send<T>(() => _dio.patch<T>(path, data: body, queryParameters: query));

  Future<T> put<T>(String path, {Object? body}) =>
      _send<T>(() => _dio.put<T>(path, data: body));

  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send<T>(() => _dio.delete<T>(path, data: body, queryParameters: query));

  /// Convenience wrapper that guarantees a JSON object back.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async =>
      _asMap(await get<dynamic>(path, query: query, cancelToken: cancelToken));

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async => _asMap(await post<dynamic>(path, body: body, query: query));

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) async =>
      _asMap(await patch<dynamic>(path, body: body));

  Future<Map<String, dynamic>> putJson(String path, {Object? body}) async =>
      _asMap(await put<dynamic>(path, body: body));

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async => _asMap(await delete<dynamic>(path, body: body, query: query));

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  Future<T> _send<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } on DioException catch (error) {
      final mapped = ApiException.fromDio(error);
      // Never log the payload: it can hold OTPs, private messages and reset
      // tokens. Status and path are enough to diagnose.
      AppLog.warn(
        'API ${error.requestOptions.method} ${error.requestOptions.path} '
        '→ ${mapped.kind.name} (${mapped.statusCode ?? '-'})',
      );
      if (mapped.endsSession) {
        await _sessionStore.clear();
        onSessionInvalidated?.call(mapped);
      }
      throw mapped;
    }
  }
}

/// Dio exposes header names as plain strings; naming them once avoids typos.
class HttpHeaders {
  const HttpHeaders._();
  static const setCookie = 'set-cookie';
}
