import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/credits_repository.dart';
import '../data/repositories/discovery_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/messaging_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/safety_repository.dart';
import '../data/repositories/dates_repository.dart';
import '../data/repositories/favorites_repository.dart';
import '../data/repositories/whatsapp_repository.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';
import 'network/session_store.dart';

/// Composition root. Everything the app depends on is reachable from here, and
/// every one of these is overridable in tests with a fake.

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Raised when the backend rejects the stored session, so the router can send
/// the member to sign in from one place instead of at every call site.
final sessionInvalidatedProvider = StateProvider<ApiException?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    sessionStore: ref.watch(sessionStoreProvider),
    onSessionInvalidated: (reason) {
      ref.read(sessionInvalidatedProvider.notifier).state = reason;
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

final contactRepositoryProvider = Provider<ContactRepository>(
  (ref) => ContactRepository(ref.watch(apiClientProvider)),
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

final whatsAppRepositoryProvider = Provider<WhatsAppRepository>(
  (ref) => WhatsAppRepository(ref.watch(apiClientProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(apiClientProvider)),
);

final datesRepositoryProvider = Provider<DatesRepository>(
  (ref) => DatesRepository(ref.watch(apiClientProvider)),
);

/// True only in debug builds. Used to keep developer affordances out of release.
final isDebugBuildProvider = Provider<bool>((ref) => kDebugMode);
