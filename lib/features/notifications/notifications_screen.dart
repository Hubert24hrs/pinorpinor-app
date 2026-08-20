import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time_ago.dart';
import '../../data/models/enums.dart';
import '../../data/models/notifications.dart';
import '../../shared/widgets/states.dart';
import 'notification_providers.dart';
import '../shell/app_drawer.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final contactRequests = ref.watch(contactRequestsProvider);
    final pendingRequests = contactRequests.valueOrNull?.pendingCount ?? 0;

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationsRepositoryProvider).markRead();
                ref
                  ..invalidate(notificationsProvider)
                  ..read(unreadBadgeProvider.notifier).clearNotificationBadge();
              } on ApiException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () async {
            ref
              ..invalidate(notificationsProvider)
              ..invalidate(contactRequestsProvider);
          },
          child: notifications.when(
            loading: () => const LoadingView(),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
              ],
            ),
            data: (page) {
              if (page.notifications.isEmpty && pendingRequests == 0) {
                return ListView(
                  children: const <Widget>[
                    SizedBox(height: AppSpacing.xxl),
                    EmptyView(
                      icon: Icons.notifications_none_rounded,
                      title: 'Nothing new',
                      message:
                          'Matches, messages and contact requests will '
                          'appear here.',
                    ),
                  ],
                );
              }

              return ContentContainer(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: <Widget>[
                    if (pendingRequests > 0)
                      _ContactRequestBanner(count: pendingRequests),
                    for (final notification in page.notifications)
                      _NotificationTile(notification: notification),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContactRequestBanner extends StatelessWidget {
  const _ContactRequestBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.badgeGoldBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.badgeGoldBorder),
      ),
      child: ListTile(
        leading: const Icon(Icons.chat_rounded, color: AppColors.badgeGoldFg),
        title: Text(
          count == 1
              ? '1 contact request waiting'
              : '$count contact requests waiting',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          'Members asking to reach you on WhatsApp. Nothing is shared until '
          'you accept.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.contactRequests),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  (IconData, Color) get _visual => switch (notification.type) {
    NotificationType.match => (Icons.favorite_rounded, AppColors.rose),
    NotificationType.message => (Icons.forum_rounded, AppColors.rose),
    NotificationType.likeReceived => (
      Icons.thumb_up_alt_rounded,
      AppColors.rose,
    ),
    NotificationType.profileVerified => (
      Icons.verified_rounded,
      AppColors.badgeVerifiedFg,
    ),
    NotificationType.contactRequest => (
      Icons.chat_rounded,
      AppColors.badgeGoldFg,
    ),
    NotificationType.contactAccepted => (
      Icons.check_circle_rounded,
      AppColors.badgeVerifiedFg,
    ),
    NotificationType.contactDeclined => (
      Icons.do_not_disturb_on_rounded,
      AppColors.textMuted,
    ),
    NotificationType.reportResolved => (
      Icons.shield_rounded,
      AppColors.badgeVerifiedFg,
    ),
    NotificationType.dateProposal ||
    NotificationType.dateAccepted ||
    NotificationType.dateDeclined => (Icons.event_rounded, AppColors.rose),
    NotificationType.system => (
      Icons.campaign_rounded,
      AppColors.textSecondary,
    ),
  };

  void _open(BuildContext context, WidgetRef ref) {
    // Mark read first so the badge is right even if the destination fails.
    ref
        .read(notificationsRepositoryProvider)
        .markRead(notificationId: notification.id)
        .then((_) => ref.invalidate(notificationsProvider), onError: (_) {});

    final conversationId = notification.conversationId;
    if (conversationId != null) {
      context.push(AppRoutes.conversationFor(conversationId));
      return;
    }
    if (notification.contactRequestId != null) {
      context.push(AppRoutes.contactRequests);
      return;
    }
    final username = notification.ownerUsername;
    if (username != null) {
      context.push(AppRoutes.profileFor(username));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _visual;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontFamily: AppTheme.sansFamily,
          fontSize: 14.5,
          fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
          color: AppColors.textMain,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          notification.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            timeAgo(notification.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!notification.isRead) ...<Widget>[
            const SizedBox(height: 5),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.rose,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () => _open(context, ref),
    );
  }
}
