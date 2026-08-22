import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/auth_repository.dart';

/// Where the app is, authentication-wise.
enum AuthPhase {
  /// Restoring a stored session at launch. The splash holds here.
  restoring,

  /// Browsing without an account. Discovery is deliberately open — the website
  /// has no login wall for browsing and the app keeps that.
  signedOut,

  signedIn,
}

@immutable
class AuthState {
  const AuthState({required this.phase, this.session, this.suspendedReason});

  final AuthPhase phase;
  final AuthSession? session;

  /// Set when the backend answered `ACCOUNT_SUSPENDED`, so the sign-in screen
  /// can explain why the member was signed out instead of silently returning.
  final String? suspendedReason;

  bool get isSignedIn => phase == AuthPhase.signedIn && session != null;
  bool get isRestoring => phase == AuthPhase.restoring;

  String? get userId => session?.userId;
  UserRole get role => session?.role ?? UserRole.unknown;
  Gender? get gender => session?.gender;

  /// Only lady accounts may upload media, mirroring the upload route's guard.
  bool get canUploadMedia => isSignedIn && role.canUploadMedia;

  static const restoring = AuthState(phase: AuthPhase.restoring);
  static const signedOut = AuthState(phase: AuthPhase.signedOut);

  AuthState copyWith({
    AuthPhase? phase,
    AuthSession? session,
    String? suspendedReason,
    bool clearSuspension = false,
  }) => AuthState(
    phase: phase ?? this.phase,
    session: session ?? this.session,
    suspendedReason: clearSuspension
        ? null
        : (suspendedReason ?? this.suspendedReason),
  );
}

/// Owns the session for the whole app.
///
/// Nothing else calls sign-in or sign-out, so there is exactly one place where
/// the session can change and exactly one place the router has to watch.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(AuthState.restoring);

  final AuthRepository _repository;

  /// Restores a stored session at launch.
  ///
  /// Failure is never fatal: an expired cookie, a suspended account or an
  /// offline device all end as "signed out" rather than a stuck splash screen.
  /// Being offline with a valid cookie keeps the session — the app stays usable
  /// and the next authenticated call will tell the truth.
  Future<void> restore() async {
    try {
      final session = await _repository.currentSession();
      state = session == null
          ? AuthState.signedOut
          : AuthState(phase: AuthPhase.signedIn, session: session);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.network) {
        // Offline. Trust the stored cookie until the server says otherwise.
        final hasCookie = await _repository.currentSessionCookieExists();
        state = hasCookie
            ? state.copyWith(phase: AuthPhase.signedOut)
            : AuthState.signedOut;
        return;
      }
      state = AuthState.signedOut;
    }
  }

  /// [identifier] is a username or an email address — the backend decides
  /// which column to search by looking for an "@".
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final session = await _repository.signIn(
      identifier: identifier,
      password: password,
    );
    state = AuthState(phase: AuthPhase.signedIn, session: session);
  }

  /// Registers, then signs the new member straight in so onboarding continues
  /// without a second credential prompt.
  ///
  /// The sign-in uses the **username**, because that is now the only
  /// identifier the account has — see [AuthRepository.join].
  Future<JoinResult> join({
    required String username,
    required String password,
    required String phone,
    required String bio,
    required Gender gender,
    required String primaryService,
    required bool isAdult,
    List<String> services = const <String>[],
    List<String> hookupServices = const <String>[],
    Map<String, String> rates = const <String, String>{},
    String? referralCode,
  }) async {
    final result = await _repository.join(
      username: username,
      password: password,
      phone: phone,
      bio: bio,
      gender: gender,
      primaryService: primaryService,
      isAdult: isAdult,
      services: services,
      hookupServices: hookupServices,
      rates: rates,
      referralCode: referralCode,
    );

    // The server normalises the username; sign in with what it stored rather
    // than with what was typed.
    await signIn(identifier: result.username ?? username, password: password);
    return result;
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = AuthState.signedOut;
  }

  /// Called when an API response invalidates the session mid-flight.
  void handleInvalidation(ApiException reason) {
    if (state.phase == AuthPhase.signedOut) return;
    state = AuthState(
      phase: AuthPhase.signedOut,
      suspendedReason: reason.kind == ApiErrorKind.accountSuspended
          ? reason.message
          : null,
    );
  }

  void clearSuspensionNotice() {
    if (state.suspendedReason == null) return;
    state = state.copyWith(clearSuspension: true);
  }

  /// Re-reads the session, e.g. after verification changes the member's status.
  Future<void> refresh() async {
    if (!state.isSignedIn) return;
    try {
      final session = await _repository.currentSession();
      if (session == null) {
        state = AuthState.signedOut;
        return;
      }
      state = AuthState(phase: AuthPhase.signedIn, session: session);
    } on ApiException {
      // Leave the current state alone — a transient failure is not a sign-out.
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((
  ref,
) {
  final controller = AuthController(ref.watch(authRepositoryProvider));

  // One subscription turns every "session rejected" anywhere in the app into a
  // single state change here.
  ref.listen<ApiException?>(sessionInvalidatedProvider, (previous, next) {
    if (next != null) controller.handleInvalidation(next);
  });

  return controller;
});
