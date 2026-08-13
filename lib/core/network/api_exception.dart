import 'package:dio/dio.dart';

/// Every failure the UI has to distinguish, in one type.
///
/// Route handlers on the website answer with `{ "error": "..." }` and a status
/// code, and a few carry a machine-readable `code` (`ACCOUNT_SUSPENDED`). The
/// mapping below turns all of that — plus transport failures — into something a
/// screen can switch on without inspecting Dio internals.
enum ApiErrorKind {
  /// No usable connection, DNS failure, or the request timed out.
  network,

  /// 401 — no session, or the session is no longer valid.
  unauthorized,

  /// 403 with `code: ACCOUNT_SUSPENDED` — banned or deactivated.
  accountSuspended,

  /// 403 without a suspension code.
  forbidden,

  /// 404.
  notFound,

  /// 409 — conflict, e.g. a username taken between check and submit.
  conflict,

  /// 402 — not enough credits.
  paymentRequired,

  /// 422/400 — the server rejected the payload.
  validation,

  /// 429 — rate limited.
  rateLimited,

  /// 503 — a dependency is switched off (card payments, unkeyed SMS provider).
  unavailable,

  /// 5xx, or anything that did not fit above.
  server,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.field,
    this.retryAfter,
    this.suggestions = const <String>[],
  });

  final ApiErrorKind kind;

  /// Safe to show to a user. Server copy is preferred where present, because the
  /// website's messages are already written for members.
  final String message;

  final int? statusCode;

  /// Machine-readable code from the server, when it sends one.
  final String? code;

  /// Which form field the server blamed, when it says.
  final String? field;

  final Duration? retryAfter;

  /// Alternative usernames offered by the registration endpoints on a 409.
  final List<String> suggestions;

  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.server ||
      kind == ApiErrorKind.rateLimited;

  /// Should the app tear the session down and send the user to sign in?
  bool get endsSession =>
      kind == ApiErrorKind.unauthorized ||
      kind == ApiErrorKind.accountSuspended;

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.network,
          message:
              'The connection timed out. Check your network and try again.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: "You're offline. Reconnect and try again.",
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: 'Request cancelled.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: 'Could not establish a secure connection.',
        );
      case DioExceptionType.badResponse:
        break;
    }

    final response = error.response;
    final status = response?.statusCode ?? 0;
    final body = response?.data;

    String? serverMessage;
    String? serverCode;
    String? field;
    var suggestions = const <String>[];

    if (body is Map) {
      final raw = body['error'];
      if (raw is String && raw.trim().isNotEmpty) serverMessage = raw.trim();
      final rawCode = body['code'];
      if (rawCode is String && rawCode.isNotEmpty) serverCode = rawCode;
      final rawField = body['field'];
      if (rawField is String && rawField.isNotEmpty) field = rawField;
      final rawSuggestions = body['suggestions'];
      if (rawSuggestions is List) {
        suggestions = rawSuggestions.map((e) => e.toString()).toList();
      }
    }

    final retryAfterHeader = response?.headers.value('retry-after');
    final retryAfterSeconds = int.tryParse(retryAfterHeader ?? '');

    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      402 => ApiErrorKind.paymentRequired,
      403 =>
        serverCode == 'ACCOUNT_SUSPENDED'
            ? ApiErrorKind.accountSuspended
            : ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      422 || 400 => ApiErrorKind.validation,
      429 => ApiErrorKind.rateLimited,
      503 => ApiErrorKind.unavailable,
      _ => status >= 500 ? ApiErrorKind.server : ApiErrorKind.server,
    };

    return ApiException(
      kind: kind,
      message: serverMessage ?? _fallbackMessage(kind),
      statusCode: status,
      code: serverCode,
      field: field,
      suggestions: suggestions,
      retryAfter: retryAfterSeconds == null
          ? null
          : Duration(seconds: retryAfterSeconds),
    );
  }

  static String _fallbackMessage(ApiErrorKind kind) => switch (kind) {
    ApiErrorKind.network => "You're offline. Reconnect and try again.",
    ApiErrorKind.unauthorized => 'Please sign in to continue.',
    ApiErrorKind.accountSuspended => 'This account has been suspended.',
    ApiErrorKind.forbidden => "You don't have access to that.",
    ApiErrorKind.notFound => 'Not found.',
    ApiErrorKind.conflict => 'That is already taken.',
    ApiErrorKind.paymentRequired => "You don't have enough credits.",
    ApiErrorKind.validation => 'Please check the details and try again.',
    ApiErrorKind.rateLimited => 'Too many attempts. Please wait a moment.',
    ApiErrorKind.unavailable =>
      'That feature is temporarily unavailable. Please try again later.',
    ApiErrorKind.server => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'ApiException(${kind.name}, $statusCode): $message';
}
