import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/session_store.dart';
import '../../core/utils/validators.dart';
import '../models/enums.dart';
import '../models/json.dart';

/// Authentication against the website's NextAuth credentials provider.
///
/// The backend has no bearer-token endpoint — it issues an `HttpOnly` JWT
/// cookie, and that same cookie is what `requireAuth()` reads on every API call.
/// Rather than fork the backend to add a second auth scheme, the app speaks the
/// browser flow exactly:
///
///   1. `GET  /api/auth/csrf`                → csrf token + csrf cookie
///   2. `POST /api/auth/callback/credentials`→ session cookie on success
///   3. `GET  /api/auth/session`             → the session, or `{}` when invalid
///
/// The cookie is then held in the Keystore/Keychain by [SessionStore]. Nothing
/// about the account — not the password, not the token — is written anywhere
/// else on the device.
///
/// Why this and not a custom mobile token endpoint: adding one would mean a
/// second credential path into a live platform, with its own expiry, revocation
/// and ban-checking to get right. Reusing the browser flow inherits every
/// protection the website already has, including the account re-read inside
/// `requireAuth()` that makes a suspension bite immediately.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  SessionStore get _session => _api.sessionStore;

  /// Is a session cookie present on the device? Says nothing about whether the
  /// backend still honours it — used only to decide what to do when the network
  /// is unreachable at launch.
  Future<bool> currentSessionCookieExists() => _session.hasSession;

  /// The signed-in member's session, or null when there is none.
  ///
  /// NextAuth answers `{}` — not a 401 — for an expired or unknown cookie, so
  /// an empty body is the signal to treat the session as gone.
  Future<AuthSession?> currentSession() async {
    if (!await _session.hasSession) return null;
    try {
      final json = await _api.getJson('/api/auth/session');
      final user = asMap(json['user']);
      if (user.isEmpty || asString(user['id']).isEmpty) {
        await _session.clear();
        return null;
      }
      return AuthSession.fromJson(json);
    } on ApiException catch (error) {
      if (error.endsSession) {
        await _session.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<String> _csrfToken() async {
    final json = await _api.getJson('/api/auth/csrf');
    final token = asString(json['csrfToken']);
    if (token.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.server,
        message: 'Could not start sign-in. Please try again.',
      );
    }
    return token;
  }

  /// Signs in with email and password.
  ///
  /// Verified against production: with `json=true` the credentials callback
  /// answers **401** for a bad credential and 200 with a session cookie for a
  /// good one. Because `authorize()` also refuses inactive and banned accounts,
  /// a 401 here covers "wrong password" and "suspended" alike — and it must stay
  /// one message, since distinguishing them would confirm an address exists.
  ///
  /// The generic 401 handling in [ApiClient] would fire the session-invalidated
  /// callback on that failure, so it is caught here: a failed sign-in attempt is
  /// not an expired session.
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final token = await _csrfToken();

    try {
      await _api.post<dynamic>(
        '/api/auth/callback/credentials',
        body: <String, String>{
          'csrfToken': token,
          'email': normalizedEmail,
          'password': password,
          'json': 'true',
          'redirect': 'false',
          'callbackUrl': '/dashboard',
        },
        // NextAuth's callback route reads a form body, exactly as a browser
        // posts it. JSON is not part of that contract.
        contentType: ApiClient.formContentType,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthorized ||
          error.kind == ApiErrorKind.forbidden) {
        throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Incorrect email or password.',
        );
      }
      rethrow;
    }

    // The cookie is the only proof that matters — read the session back rather
    // than trusting the callback's own response body.
    final session = await currentSession();
    if (session == null) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Incorrect email or password.',
      );
    }
    return session;
  }

  /// Creates a member account through `/api/member/join`.
  ///
  /// This is the route the website's own signup form uses, and the only one that
  /// grants the welcome credits, sets the 24-hour featured window and applies a
  /// referral code. Age is validated server-side; the client check below only
  /// saves a round trip.
  Future<JoinResult> join({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required DateTime birthDate,
    required Gender gender,
    required String countryCode,
    String? city,
    String? phone,
    String? bio,
    String? tagline,
    List<String> dateTypes = const <String>[],
    InterestedIn? interestedIn,
    String? referralCode,
  }) async {
    final ageError = Validators.birthDate(birthDate);
    if (ageError != null) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: ageError,
        field: 'birthDate',
      );
    }

    final json = await _api.postJson(
      '/api/member/join',
      body: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
        'displayName': displayName.trim(),
        'username': UsernameRules.normalize(username),
        // Date only — the backend parses it with `new Date(...)`, and sending a
        // local timestamp could shift the day across a timezone boundary.
        'birthDate': _dateOnly(birthDate),
        'gender': gender.wire,
        'country': countryCode,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
        if (tagline != null && tagline.trim().isNotEmpty)
          'tagline': tagline.trim(),
        if (dateTypes.isNotEmpty) 'dateTypes': dateTypes,
        if (interestedIn != null) 'interestedIn': interestedIn.wire,
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referralCode': referralCode.trim().toUpperCase(),
      },
    );

    return JoinResult(
      userId: asString(json['userId']),
      referralCode: asStringOrNull(json['referralCode']),
      message: asStringOrNull(json['message']),
    );
  }

  /// Live availability feedback for the signup form. Advisory only — the unique
  /// index decides at insert time, and both registration routes translate the
  /// resulting conflict into the same message.
  Future<UsernameAvailability> checkUsername(String username) async {
    final json = await _api.getJson(
      '/api/username/available',
      query: <String, dynamic>{'username': UsernameRules.normalize(username)},
    );
    return UsernameAvailability(
      available: json['available'] is bool ? json['available'] as bool : null,
      valid: asBool(json['valid'], fallback: true),
      message: asStringOrNull(json['message']),
      suggestions: asStringList(json['suggestions']),
    );
  }

  /// Always reports success, whether or not the address exists — the backend
  /// refuses to become an account-existence oracle, and the app must not leak
  /// what the API deliberately hides.
  Future<void> requestPasswordReset(String email) async {
    await _api.postJson(
      '/api/forgot-password',
      body: <String, String>{'email': email.trim().toLowerCase()},
    );
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _api.putJson(
      '/api/forgot-password',
      body: <String, String>{'token': token, 'password': password},
    );
  }

  /// Sends a 6-digit code to the member's email or phone.
  Future<void> sendVerificationCode(
    VerificationChannel channel, {
    String? phone,
  }) async {
    await _api.postJson(
      '/api/auth/verify/send',
      body: <String, dynamic>{
        'channel': channel.wire,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
  }

  /// Confirms a code. Verified status is set by the backend and nowhere else —
  /// the result here only reports what the server decided.
  Future<VerificationState> confirmVerificationCode({
    required VerificationChannel channel,
    required String code,
  }) async {
    final json = await _api.postJson(
      '/api/auth/verify/confirm',
      body: <String, String>{'channel': channel.wire, 'code': code.trim()},
    );
    return VerificationState(
      emailVerified: asBool(json['emailVerified']),
      phoneVerified: asBool(json['phoneVerified']),
      fullyVerified: asBool(json['fullyVerified']),
    );
  }

  /// Signs out on the server and then locally.
  ///
  /// The local clear runs even if the network call fails: leaving a session
  /// cookie on the device after the member asked to leave is the worse failure,
  /// and the cookie is useless to anyone who cannot read secure storage anyway.
  Future<void> signOut() async {
    try {
      final token = await _csrfToken();
      await _api.post<dynamic>(
        '/api/auth/signout',
        body: <String, String>{'csrfToken': token, 'json': 'true'},
        contentType: ApiClient.formContentType,
      );
    } on ApiException {
      // Offline, or the session was already dead. Fall through.
    } on DioException {
      // Same: local sign-out must not depend on the network.
    } finally {
      await _api.sessionStore.clear();
    }
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// What `/api/auth/session` returns: the JWT's public claims.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.username,
    required this.displayName,
    required this.role,
    this.gender,
    this.avatarPath,
    this.expiresAt,
  });

  final String userId;
  final String email;
  final String username;
  final String displayName;
  final UserRole role;
  final Gender? gender;

  /// `/api/media/<id>` — a stable proxy, never a signed URL, because the JWT
  /// outlives any signature.
  final String? avatarPath;

  final DateTime? expiresAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return AuthSession(
      userId: asString(user['id']),
      email: asString(user['email']),
      username: asString(user['username']),
      displayName: asString(user['name'], fallback: asString(user['username'])),
      role: UserRole.parse(user['role']),
      gender: Gender.parse(user['gender']),
      avatarPath: asStringOrNull(user['image']),
      expiresAt: asDateOrNull(json['expires']),
    );
  }
}

class JoinResult {
  const JoinResult({required this.userId, this.referralCode, this.message});

  final String userId;
  final String? referralCode;
  final String? message;
}

class UsernameAvailability {
  const UsernameAvailability({
    required this.available,
    required this.valid,
    this.message,
    this.suggestions = const <String>[],
  });

  /// Null when the backend could not check — it never claims a name is free
  /// when the lookup failed.
  final bool? available;

  final bool valid;
  final String? message;
  final List<String> suggestions;

  bool get isTaken => available == false && valid;
  bool get isFree => available == true;
}

class VerificationState {
  const VerificationState({
    required this.emailVerified,
    required this.phoneVerified,
    required this.fullyVerified,
  });

  final bool emailVerified;
  final bool phoneVerified;
  final bool fullyVerified;
}
