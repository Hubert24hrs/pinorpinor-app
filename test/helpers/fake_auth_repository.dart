import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/models/enums.dart';
import 'package:pinorpinor_app/data/repositories/auth_repository.dart';

import 'fake_secure_storage.dart';

/// A scriptable [AuthRepository].
///
/// It extends the real class rather than reimplementing an interface, so the
/// method signatures cannot drift out of step with production code — if
/// `signIn` gains a parameter, this fails to compile instead of silently
/// testing an obsolete shape.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.signInError,
    this.joinError,
    AuthSession? session,
    this.usernameAvailability,
  }) : _session = session ?? defaultSession,
       super(
         ApiClient(sessionStore: SessionStore(storage: FakeSecureStorage())),
       );

  /// Thrown by [signIn] when set.
  final ApiException? signInError;

  /// Thrown by [join] when set.
  final ApiException? joinError;

  final UsernameAvailability? usernameAvailability;

  final AuthSession _session;

  /// (email, password) pairs the screen submitted.
  final List<(String, String)> signInCalls = <(String, String)>[];

  final List<Map<String, Object?>> joinCalls = <Map<String, Object?>>[];

  int signOutCalls = 0;
  int passwordResetRequests = 0;

  static const AuthSession defaultSession = AuthSession(
    userId: 'test-user',
    email: 'member@example.com',
    username: 'member',
    displayName: 'Member',
    role: UserRole.woman,
    gender: Gender.woman,
  );

  @override
  Future<bool> currentSessionCookieExists() async => false;

  @override
  Future<AuthSession?> currentSession() async => null;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    signInCalls.add((identifier.trim().toLowerCase(), password));
    final error = signInError;
    if (error != null) throw error;
    return _session;
  }

  @override
  Future<JoinResult> join({
    required String username,
    required String password,
    required String phone,
    required String bio,
    required List<String> services,
    required bool isAdult,
    String? referralCode,
  }) async {
    joinCalls.add(<String, Object?>{
      'username': username,
      'phone': phone,
      'bio': bio,
      'services': services,
      'isAdult': isAdult,
      'referralCode': referralCode,
    });
    final error = joinError;
    if (error != null) throw error;
    return JoinResult(userId: 'test-user', username: username);
  }

  @override
  Future<UsernameAvailability> checkUsername(String username) async =>
      usernameAvailability ??
      const UsernameAvailability(available: true, valid: true);

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetRequests++;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

/// Wires a fake into the provider graph.
List<Override> fakeAuthOverrides(FakeAuthRepository repository) => <Override>[
  authRepositoryProvider.overrideWithValue(repository),
];
