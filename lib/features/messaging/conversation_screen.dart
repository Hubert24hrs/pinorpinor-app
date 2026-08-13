import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time_ago.dart';
import '../../core/utils/validators.dart';
import '../../data/models/messaging.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import '../moderation/report_block_sheet.dart';
import 'messaging_providers.dart';

/// One conversation.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _composerController.addListener(() {
      final canSend = _composerController.text.trim().isNotEmpty;
      if (canSend != _canSend) setState(() => _canSend = canSend);
    });
    _scrollController.addListener(() {
      // The list is reversed, so `maxScrollExtent` is the *oldest* end.
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(threadProvider(widget.conversationId).notifier).loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composerController.text;
    final error = Validators.messageBody(text);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _composerController.clear();
    await HapticFeedback.selectionClick();
    await ref.read(threadProvider(widget.conversationId).notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(threadProvider(widget.conversationId));
    final me = ref.watch(authControllerProvider).userId ?? '';

    // The partner comes from the conversation list, which is already loaded
    // when arriving from Messages. Opening straight from a deep link falls back
    // to a neutral header rather than blocking on a second request.
    final summary = ref
        .watch(conversationsProvider)
        .valueOrNull
        ?.where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;
    final partner = summary?.partner;
    final isUnmatched = summary?.isUnmatched ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Avatar(
              url: partner?.avatarUrl,
              initial: partner?.displayName ?? 'M',
              size: 36,
              isVerified: partner?.isVerified ?? false,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    partner?.displayName ?? 'Conversation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (partner?.isAvailableToday ?? false)
                    Text(
                      'Available today',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (partner != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    context.push(AppRoutes.profileFor(partner.username));
                  case 'safety':
                    showReportBlockSheet(
                      context: context,
                      ref: ref,
                      userId: partner.id,
                      displayName: partner.displayName,
                      onBlocked: () {
                        ref.invalidate(conversationsProvider);
                        if (context.canPop()) context.pop();
                      },
                    );
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_outline_rounded, size: 20),
                    title: Text('View profile'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'safety',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shield_outlined, size: 20),
                    title: Text('Report or block'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ContentContainer(
                child: Builder(
                  builder: (context) {
                    if (thread.isLoading && thread.messages.isEmpty) {
                      return const LoadingView();
                    }
                    if (thread.error != null && thread.messages.isEmpty) {
                      return ErrorView(
                        error: thread.error!,
                        onRetry: () => ref
                            .read(
                              threadProvider(widget.conversationId).notifier,
                            )
                            .load(),
                      );
                    }
                    if (thread.messages.isEmpty) {
                      return EmptyView(
                        icon: Icons.waving_hand_rounded,
                        title: 'Say hello',
                        message: partner == null
                            ? 'Start the conversation.'
                            : 'You matched with ${partner.displayName}. '
                                  'Open with something they mentioned on their '
                                  'profile.',
                      );
                    }
                    return _MessageList(
                      thread: thread,
                      currentUserId: me,
                      controller: _scrollController,
                      onRetry: (message) => ref
                          .read(threadProvider(widget.conversationId).notifier)
                          .retry(message),
                    );
                  },
                ),
              ),
            ),

            if (thread.sendError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  thread.sendError!,
                  style: const TextStyle(
                    fontFamily: AppTheme.sansFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),

            _Composer(
              controller: _composerController,
              canSend: _canSend && !isUnmatched,
              // The backend refuses messages on an ended match with a 403, so
              // the composer says why rather than letting the send fail.
              disabledReason: isUnmatched
                  ? 'This match has ended. You can no longer send messages.'
                  : null,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.thread,
    required this.currentUserId,
    required this.controller,
    required this.onRetry,
  });

  final ThreadState thread;
  final String currentUserId;
  final ScrollController controller;
  final void Function(Message) onRetry;

  @override
  Widget build(BuildContext context) {
    // Reversed so new messages appear at the bottom without a scroll jump, and
    // so the keyboard opening does not shift the whole history.
    final ordered = thread.messages.reversed.toList(growable: false);

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      itemCount: ordered.length + (thread.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= ordered.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = ordered[index];
        // `index + 1` is the *older* neighbour because the list is reversed.
        final older = index + 1 < ordered.length ? ordered[index + 1] : null;
        final showDayDivider =
            older == null || !_sameDay(older.createdAt, message.createdAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showDayDivider)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgMuted,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      messageDayLabel(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            _MessageBubble(
              message: message,
              isMine: message.isMine(currentUserId),
              onRetry: () => onRetry(message),
            ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onRetry,
  });

  final Message message;
  final bool isMine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.76;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth.clamp(200, 520)),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: isMine ? AppColors.roseGradient : null,
          color: isMine ? null : AppColors.bgSecondary,
          border: isMine ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.xs),
            bottomRight: Radius.circular(isMine ? AppRadius.xs : AppRadius.lg),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if ((message.content ?? '').isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.content!,
                  style: TextStyle(
                    fontFamily: AppTheme.sansFamily,
                    fontSize: 15,
                    height: 1.4,
                    color: isMine ? Colors.white : AppColors.textMain,
                  ),
                ),
              ),
            if (message.mediaUrl != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ProfileImage(
                url: message.mediaUrl,
                height: 180,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ],
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (message.failed) ...<Widget>[
                  GestureDetector(
                    onTap: onRetry,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const <Widget>[
                        Icon(
                          Icons.refresh_rounded,
                          size: 12,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Not sent · tap to retry',
                          style: TextStyle(
                            fontFamily: AppTheme.sansFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    formatTime(message.createdAt),
                    style: TextStyle(
                      fontFamily: AppTheme.sansFamily,
                      fontSize: 10.5,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                    ),
                  ),
                  if (message.isPending) ...<Widget>[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 9,
                      height: 9,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMine ? Colors.white70 : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onSend,
    this.disabledReason,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    if (disabledReason != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.bgMuted,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Text(
          disabledReason!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ContentContainer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Write a message…',
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Semantics(
                button: true,
                label: 'Send message',
                child: InkWell(
                  onTap: canSend ? onSend : null,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    width: AppSpacing.minTouchTarget,
                    height: AppSpacing.minTouchTarget,
                    decoration: BoxDecoration(
                      gradient: canSend ? AppColors.roseGradient : null,
                      color: canSend ? null : AppColors.bgMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 19,
                      color: canSend ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
