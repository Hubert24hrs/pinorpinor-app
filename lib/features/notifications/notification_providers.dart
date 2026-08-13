import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/notifications.dart';
import '../auth/auth_controller.dart';

/// Badge counts for the shell.
@immutable
class UnreadCounts {
  const UnreadCounts({this.notifications = 0, this.messages = 0});

  final int notifications;
  final int messages;

  static const zero = UnreadCounts();

  UnreadCounts copyWith({int? notifications, int? messages}) => UnreadCounts(
    notifications: notifications ?? this.notifications,
    messages: messages ?? this.messages,
  );
}

/// Polls for unread counts while the app is in the foreground.
///
/// **Why polling rather than push.** The backend has no push infrastructure at
/// all: no device-token table, no FCM credential, no send path. Adding Firebase
/// Messaging to the client alone would produce an app that registers for
/// notifications nobody can send. Polling delivers the badge and the local
/// notification today, against endpoints that already exist, and the FCM work is
/// specified in `docs/DEPLOYMENT.md` as a backend change with an explicit
/// migration — see "Push notifications" there.
///
/// The poll is cheap (one indexed count) and stops entirely when signed out.
class UnreadCountsNotifier extends StateNotifier<UnreadCounts> {
  UnreadCountsNotifier(this._ref) : super(UnreadCounts.zero);

  final Ref _ref;
  Timer? _timer;
  bool _inFlight = false;

  void start() {
    _timer?.cancel();
    unawaited(refresh());
    _timer = Timer.periodic(
      AppConfig.notificationPollInterval,
      (_) => unawaited(refresh()),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = UnreadCounts.zero;
  }

  Future<void> refresh() async {
    if (_inFlight) return;
    if (!_ref.read(authControllerProvider).isSignedIn) return;

    _inFlight = true;
    try {
      final page = await _ref
          .read(notificationsRepositoryProvider)
          .list(limit: 1);
      final conversations = await _ref
          .read(messagingRepositoryProvider)
          .conversations();
      final me = _ref.read(authControllerProvider).userId;

      final unreadThreads = me == null
          ? 0
          : conversations.where((c) => c.unreadFor(me)).length;

      if (!mounted) return;
      state = UnreadCounts(
        notifications: page.unreadCount,
        messages: unreadThreads,
      );
    } on ApiException {
      // A failed poll is not worth surfacing — the badge simply does not move.
    } finally {
      _inFlight = false;
    }
  }

  /// Called when the member opens the notifications tab.
  void clearNotificationBadge() => state = state.copyWith(notifications: 0);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final unreadBadgeProvider =
    StateNotifierProvider<UnreadCountsNotifier, UnreadCounts>((ref) {
      final notifier = UnreadCountsNotifier(ref);

      // Tie the poller's life to the session: it starts on sign-in, stops on
      // sign-out, and never runs for an anonymous browser.
      ref.listen<AuthState>(authControllerProvider, (previous, next) {
        if (next.isSignedIn && previous?.isSignedIn != true) {
          notifier.start();
        } else if (!next.isSignedIn) {
          notifier.stop();
        }
      }, fireImmediately: true);

      return notifier;
    });

/// The notifications list itself.
final notificationsProvider = FutureProvider.autoDispose<NotificationPage>((
  ref,
) async {
  final repository = ref.watch(notificationsRepositoryProvider);
  return repository.list();
});

/// Pending WhatsApp contact requests addressed to the member.
final contactRequestsProvider = FutureProvider.autoDispose<ContactRequestInbox>(
  (ref) async {
    return ref.watch(contactRepositoryProvider).inbox();
  },
);

/// Requests the member has sent, so they can see what is still pending.
final sentContactRequestsProvider =
    FutureProvider.autoDispose<ContactRequestInbox>((ref) async {
      return ref.watch(contactRepositoryProvider).inbox(box: 'sent');
    });
