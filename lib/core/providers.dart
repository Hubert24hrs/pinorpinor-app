import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/credits_repository.dart';
import '../data/repositories/discovery_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/messaging_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/contact_access_repository.dart';
import '../data/repositories/presence_repository.dart';
import '../data/repositories/support_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/safety_repository.dart';
import '../data/repositories/dates_repository.dart';
import '../data/repositories/favorites_repository.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';
import 'network/session_store.dart';

/// Composition root. Everything the app depends on is reachable from here, and
/// every one of these is overridable in tests with a fake.

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Raised when the backend rejects the stored session, so the router can send
/// the member to sign in from one place instead of at every call site.
final sessionInvalidatedProvider = StateProvider<ApiException?>((ref) => null);

/// Set when any call answers `PASSWORD_CHANGE_REQUIRED`.
///
/// An admin can reset a password without learning it, and until the member sets
/// a new one **every authenticated endpoint refuses**. So this is not one
/// screen's error to render — it is the state of the whole app, and the router
/// reads it in one place rather than each screen guessing what to do with a 403
/// on something the member owns.
final passwordChangeRequiredProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    sessionStore: ref.watch(sessionStoreProvider),
    onSessionInvalidated: (reason) {
      ref.read(sessionInvalidatedProvider.notifier).state = reason;
    },
    onPasswordChangeRequired: () {
      ref.read(passwordChangeRequiredProvider.notifier).state = true;
    },
  );
  ref.onDispose(() => client.raw.close(force: true));
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(apiClientProvider)),
);

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => MessagingRepository(ref.watch(apiClientProvider)),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

/// Opening a paid WhatsApp chat. Replaces the contact-request flow, whose
/// endpoints the website removed on 2026-08-23.
final contactAccessRepositoryProvider = Provider<ContactAccessRepository>(
  (ref) => ContactAccessRepository(ref.watch(apiClientProvider)),
);

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(ref.watch(apiClientProvider)),
);

final presenceRepositoryProvider = Provider<PresenceRepository>(
  (ref) => PresenceRepository(ref.watch(apiClientProvider)),
);

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(apiClientProvider)),
);

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(apiClientProvider)),
);

final creditsRepositoryProvider = Provider<CreditsRepository>(
  (ref) => CreditsRepository(ref.watch(apiClientProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(apiClientProvider)),
);

final datesRepositoryProvider = Provider<DatesRepository>(
  (ref) => DatesRepository(ref.watch(apiClientProvider)),
);

/// True only in debug builds. Used to keep developer affordances out of release.
final isDebugBuildProvider = Provider<bool>((ref) => kDebugMode);
