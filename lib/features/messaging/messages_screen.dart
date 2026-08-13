import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time_ago.dart';
import '../../data/models/messaging.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import 'messaging_providers.dart';

/// The conversation list.
///
/// Threads exist only where there is a match — the backend creates a
/// conversation automatically when two members like each other, and there is no
/// route that opens one otherwise. That is why the empty state points at
/// discovery rather than at a "new message" button that could not work.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final me = ref.watch(authControllerProvider).userId ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded),
            tooltip: 'Your matches',
            onPressed: () => context.push(AppRoutes.matches),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () async {
            ref.invalidate(conversationsProvider);
            await ref
                .read(conversationsProvider.future)
                .catchError((_) => <ConversationSummary>[]);
          },
          child: conversations.when(
            loading: () => ListView.separated(
              itemCount: 6,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, _) => const ListTile(
                leading: Skeleton.circle(size: 48),
                title: Skeleton(width: 120, height: 14),
                subtitle: Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Skeleton(width: 180, height: 12),
                ),
              ),
            ),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(conversationsProvider),
                ),
              ],
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    EmptyView(
                      icon: Icons.forum_outlined,
                      title: 'No conversations yet',
                      message:
                          'When you and another member like each other, a '
                          'conversation opens here automatically.',
                      actionLabel: 'Start discovering',
                      onAction: () => context.go(AppRoutes.discover),
                    ),
                  ],
                );
              }

              return ContentContainer(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 76),
                  itemBuilder: (context, index) => _ConversationTile(
                    conversation: items[index],
                    currentUserId: me,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  final ConversationSummary conversation;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final partner = conversation.partner;
    final unread = conversation.unreadFor(currentUserId);
    final name = partner?.displayName ?? 'Member';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: Avatar(
        url: partner?.avatarUrl,
        initial: name,
        size: 52,
        isVerified: partner?.isVerified ?? false,
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.sansFamily,
                fontSize: 15,
                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          ),
          if (conversation.lastMessageAt != null)
            Text(
              timeAgo(conversation.lastMessageAt!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: <Widget>[
            if (conversation.isUnmatched) ...<Widget>[
              const Icon(
                Icons.link_off_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                conversation.isUnmatched
                    ? 'This match has ended'
                    : conversation.lastMessagePreview ?? 'Say hello',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.sansFamily,
                  fontSize: 13,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                  color: unread ? AppColors.textMain : AppColors.textSecondary,
                ),
              ),
            ),
            if (unread) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.rose,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
      onTap: () =>
          context.push(AppRoutes.conversationFor(conversation.conversationId)),
    );
  }
}
