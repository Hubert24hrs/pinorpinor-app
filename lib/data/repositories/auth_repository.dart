import 'package:dio/dio.dart';

import '../../core/constants/services.dart';
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

  /// Signs in with a username *or* an email address, and a password.
  ///
  /// **The field is `identifier`, not `email`.** Registration stopped
  /// collecting an address on 2026-08-14 (migration
  /// `20260814000000_emailless_signup`), so `authorize()` in the website's
  /// `src/lib/auth.ts` now reads `credentials.identifier` and decides which
  /// column to look in by whether the value contains an "@":
  ///
  /// ```ts
  /// const where = value.includes("@") ? { email: value } : { username: value };
  /// ```
  ///
  /// Posting `email` leaves `credentials.identifier` undefined, `authorize()`
  /// returns null on its first guard, and **every sign-in fails with 401** — a
  /// wrong password and a wrong field name are indistinguishable from here.
  /// That is exactly what the app shipped with, which is why no signed-in flow
  /// could ever have worked against the current backend.
  ///
  /// The value is lowercased because both columns are stored folded: emails on
  /// write, usernames by a database CHECK. The website folds it the same way
  /// before querying.
  ///
  /// Verified against production: with `json=true` the credentials callback
  /// answers **401** for a bad credential and 200 with a session cookie for a
  /// good one. Because `authorize()` also refuses inactive and banned accounts,
  /// a 401 here covers "wrong password" and "suspended" alike — and it must stay
  /// one message, since distinguishing them would confirm an account exists.
  ///
  /// The generic 401 handling in [ApiClient] would fire the session-invalidated
  /// callback on that failure, so it is caught here: a failed sign-in attempt is
  /// not an expired session.
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    final normalized = identifier.trim().toLowerCase();
    final token = await _csrfToken();

    try {
      await _api.post<dynamic>(
        '/api/auth/callback/credentials',
        body: <String, String>{
          'csrfToken': token,
          'identifier': normalized,
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
          message: 'Incorrect username or password.',
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
        message: 'Incorrect username or password.',
      );
    }
    return session;
  }

  /// Creates a member account through `/api/member/join`.
  ///
  /// **Six fields, and no email address.** The route was rebuilt on
  /// 2026-08-14 (migration `20260814000000_emailless_signup`) down to
  /// username, password, WhatsApp number, bio, services and an 18+
  /// confirmation. Email, date of birth, gender, country and display name were
  /// all removed from it — sending them is harmless but pointless, and the
  /// four fields this app used to send as *required* are simply not read any
  /// more.
  ///
  /// Three consequences worth knowing before changing anything here:
  ///
  /// - **`isAdult` must be `true`** or the route rejects the request outright.
  ///   It is an assertion by the member, not a verification by us; its whole
  ///   value is that there is a record the question was asked and answered.
  /// - **There is no password-reset path for accounts created this way.**
  ///   `/api/forgot-password` looks a member up by address and there is
  ///   nothing to look up, so a forgotten password is a lost account. The join
  ///   screen says so before the member commits.
  /// - **The country comes from the phone number**, resolved server-side by
  ///   `countryFromPhone`. Discovery scopes on `countryCode`, so a member
  ///   whose number does not resolve is discoverable by nobody until they set
  ///   a location in Edit Profile.
  ///
  /// Gender is forced to `WOMAN` server-side. This route only creates the
  /// listing accounts; it is not a general registration endpoint.
  Future<JoinResult> join({
    required String username,
    required String password,
    required String phone,
    required String bio,
    required List<String> services,
    required bool isAdult,
    String? referralCode,
  }) async {
    // Checked here as well as server-side so the member is not told "you must
    // confirm you are 18" by a round trip they could have been spared.
    if (!isAdult) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message:
            'You must confirm that you are 18 or over to create a profile.',
        field: 'isAdult',
      );
    }

    // Whitelisted against the catalogue before sending. The backend does this
    // too — doing it here means an id retired since the screen was built is
    // dropped quietly rather than failing the whole registration.
    final List<String> cleanServices = sanitizeServiceIds(services);
    if (cleanServices.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Select at least one service.',
        field: 'services',
      );
    }

    final json = await _api.postJson(
      '/api/member/join',
      body: <String, dynamic>{
        'username': UsernameRules.normalize(username),
        'password': password,
        'phone': phone.trim(),
        'bio': bio.trim(),
        'services': cleanServices,
        'isAdult': true,
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referralCode': referralCode.trim().toUpperCase(),
      },
    );

    return JoinResult(
      userId: asString(json['userId']),
      username: asStringOrNull(json['username']),
      countryCode: asStringOrNull(json['countryCode']),
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
  const JoinResult({
    required this.userId,
    this.username,
    this.countryCode,
    this.referralCode,
    this.message,
  });

  final String userId;

  /// The normalised username the account was actually created with — the
  /// member may have typed a different case.
  final String? username;

  /// Resolved from the WhatsApp number server-side. **Null means discovery
  /// cannot place them**, and the join flow says so rather than leaving them
  /// invisible without explanation.
  final String? countryCode;

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
