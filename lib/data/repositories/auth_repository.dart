import 'package:dio/dio.dart';

import '../../core/constants/primary_services.dart';
import '../../core/constants/service_features.dart';
import '../../core/constants/services.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/session_store.dart';
import '../../core/utils/age.dart';
import '../../core/utils/validators.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/rates.dart';

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

  /// Sends a verification code to a WhatsApp number.
  ///
  /// [purpose] is `REGISTRATION` or `PASSWORD_RESET`, and the route treats the
  /// two very differently on purpose:
  ///
  ///   * for a **reset** it answers the same way whether or not an account
  ///     exists, because a different answer would turn this endpoint into a way
  ///     of asking "is this number registered here" — on an adult platform that
  ///     is the disclosure, not the code;
  ///   * for **registration** it reports real errors, because nobody has an
  ///     account yet so there is nothing to leak and the caller needs to know.
  ///
  /// Rate limited per number and per IP. The two stop different things: the
  /// first protects a real person from being messaged repeatedly, the second
  /// stops one client walking a list of numbers.
  Future<void> sendWhatsAppCode({
    required String phone,
    String purpose = 'PASSWORD_RESET',
  }) async {
    await _api.postJson(
      '/api/auth/whatsapp/send',
      body: <String, String>{'phone': phone.trim(), 'purpose': purpose},
    );
  }

  /// Exchanges a code for a proof.
  ///
  /// The proof is an HMAC bound to the verification row **and** the phone
  /// number, so it cannot be forged and cannot be moved to a different number.
  /// The app holds it only for as long as it takes to hand it back to the reset
  /// or registration call, and never stores it.
  Future<String> verifyWhatsAppCode({
    required String phone,
    required String code,
    String purpose = 'PASSWORD_RESET',
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/api/auth/whatsapp/verify',
      body: <String, String>{
        'phone': phone.trim(),
        'code': code.trim(),
        'purpose': purpose,
      },
    );
    return asString(json['proof']);
  }

  /// Sets a new password using a WhatsApp proof instead of an emailed link.
  ///
  /// **This is the recovery path the app spent a week telling members did not
  /// exist.** Registration stopped collecting email addresses on 2026-08-14, so
  /// `/api/forgot-password` had nothing to look anyone up by and a forgotten
  /// password meant a lost account. The website shipped this on 2026-08-22;
  /// until 2026-08-25 the app's own join screen still warned that a forgotten
  /// password could never be recovered, which was false and frightening.
  ///
  /// Returns the username the password now belongs to, so the sign-in screen can
  /// prefill it.
  Future<String> resetPasswordWithWhatsApp({
    required String phone,
    required String proof,
    required String password,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/api/auth/whatsapp/reset-password',
      body: <String, String>{
        'phone': phone.trim(),
        'proof': proof,
        'password': password,
      },
    );
    return asString(json['username']);
  }

  /// Creates a member account through `/api/member/join`.
  ///
  /// **No email address.** The route was rebuilt on 2026-08-14 (migration
  /// `20260814000000_emailless_signup`) and extended again on 2026-08-21
  /// (`20260821000000_primary_service_and_referrals`). Email, date of birth,
  /// country and display name are not read at all.
  ///
  /// ## Four things the route rejects the request without
  ///
  /// - **`isAdult` must be `true`.** An assertion by the member, not a
  ///   verification by us; its whole value is that there is a record the
  ///   question was asked and answered.
  /// - **`gender` must be `WOMAN` or `MAN`.** Required since 2026-08-21, when
  ///   men could register for the first time. The route maps it through a
  ///   closed server-side table to `role` and `interestedIn` rather than
  ///   trusting the wire, because discovery filters on gender and an unexpected
  ///   value would put an account somewhere none of those queries look. Sending
  ///   nothing - which this app did until this was fixed - is a 400 every time,
  ///   and a 400 on registration is indistinguishable from a broken app.
  /// - **`primaryService` must be one of the six ids** in
  ///   `lib/core/constants/primary_services.dart`. Exactly one, required and
  ///   whitelisted: it is the badge on the member's card and it decides whether
  ///   the hookup block below is stored at all, so an unrecognised value is
  ///   rejected rather than dropped.
  /// - **`birthYear` must be a year that makes the member 18 or over.**
  ///   Added 2026-08-21. The full date of birth was dropped on 2026-08-14, which
  ///   left `isAdult` as the only thing between a minor and an account for eight
  ///   days; a year restores a server-side bound. It is stored in its own column
  ///   and **never synthesised into a `birthDate`** — a 1 January would be
  ///   indistinguishable later from a real date, and real ones exist here.
  /// - **`username` and `password`**, as before.
  ///
  /// ## The feature gate
  ///
  /// `serviceFeatures` is validated **against the catalogue of the service that
  /// was chosen**. Every one of the six has its own list as of 2026-08-22, ids
  /// are prefixed per catalogue so none is valid under two, and anything from
  /// another catalogue is dropped. `rates` remain Hookup-only.
  ///
  /// Posting either under the wrong service stores nothing and still answers
  /// 200 - the request is answerable, and the stored row simply must never
  /// contradict the badge on the card. This client applies the same gate before
  /// sending, so nothing left behind in a form's state can leak into the
  /// payload.
  ///
  /// ## `whatsappProof`
  ///
  /// Optional here and required by the route only when `WHATSAPP_OTP_ENABLED`
  /// is on. It is the HMAC returned by `/api/auth/whatsapp/verify`, bound to the
  /// verification row and the number, so it cannot be forged or moved to a
  /// different number. Sent when the app has one; the route decides whether it
  /// was needed.
  ///
  /// `services` is optional now: registration asks only for the one primary
  /// service, and the 31-entry activity catalogue is offered in Edit Profile
  /// instead, which is what keeps signup short.
  ///
  /// Two consequences unchanged from 2026-08-14:
  ///
  /// - **There is no password-reset path for accounts created this way.**
  ///   `/api/forgot-password` looks a member up by address and there is nothing
  ///   to look up, so a forgotten password is a lost account. The join screen
  ///   says so before the member commits.
  /// - **The country comes from the phone number**, resolved server-side by
  ///   `countryFromPhone`. Discovery scopes on `countryCode`, so a member whose
  ///   number does not resolve is discoverable by nobody until they set a
  ///   location in Edit Profile.
  ///
  /// **Rates are sent in MAJOR units, as typed.** `parseRateInput` converts them
  /// server-side against the currency the phone number resolves to; converting
  /// here as well is how a rate ends up stored a hundred times out.
  Future<JoinResult> join({
    required String username,
    required String password,
    required String phone,
    required String bio,
    required Gender gender,
    required String primaryService,
    required bool isAdult,
    required String birthYear,
    List<String> services = const <String>[],
    List<String> serviceFeatures = const <String>[],
    Map<String, String> rates = const <String, String>{},
    String? referralCode,
    String? whatsappProof,
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

    // Whitelisted before sending, same as the primary service below. The
    // backend does this too - doing it here means an id retired since the
    // screen was built is dropped quietly rather than failing the registration.
    final List<String> cleanServices = sanitizeServiceIds(services);

    final String? cleanPrimary = sanitizePrimaryService(primaryService);
    if (cleanPrimary == null) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Choose the one service you are here for.',
        field: 'primaryService',
      );
    }

    // Checked here as well so the member is told before a round trip, and with
    // the backend's own wording so they never see two explanations for one
    // refusal.
    final BirthYearCheck yearCheck = validateBirthYear(birthYear);
    if (yearCheck is BirthYearInvalid) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: yearCheck.message,
        field: 'birthYear',
      );
    }

    // The gate, applied on the way out. The server enforces it independently,
    // so features sent under the wrong service would simply be discarded - but
    // a client that keeps hidden answers is a client that eventually submits
    // one.
    final bool wantsHookup = offersHookup(cleanPrimary);
    final List<String> cleanFeatures = sanitizeServiceFeatures(
      serviceFeatures,
      primaryService: cleanPrimary,
    );

    final json = await _api.postJson(
      '/api/member/join',
      body: <String, dynamic>{
        'username': UsernameRules.normalize(username),
        'password': password,
        'phone': phone.trim(),
        'bio': bio.trim(),
        'gender': gender.wire,
        'birthYear': (yearCheck as BirthYearValid).year,
        'primaryService': cleanPrimary,
        'services': cleanServices,
        'serviceFeatures': cleanFeatures,
        if (wantsHookup) 'rates': MemberRates.patchBody(rates),
        'isAdult': true,
        if (whatsappProof != null && whatsappProof.trim().isNotEmpty)
          'whatsappProof': whatsappProof.trim(),
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
