import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time_ago.dart';
import '../../data/models/enums.dart';
import '../../data/models/notifications.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import 'notification_providers.dart';

/// The WhatsApp consent inbox.
///
/// This screen is the entire reason a member's phone number stays private. A
/// request arrives here; until the owner taps Accept, `/api/profile/…/whatsapp`
/// refuses to resolve their number at all — and refuses with the same response
/// it gives for a profile that has no number, so a declined requester learns
/// nothing about why.
class ContactRequestsScreen extends ConsumerStatefulWidget {
  const ContactRequestsScreen({super.key});

  @override
  ConsumerState<ContactRequestsScreen> createState() =>
      _ContactRequestsScreenState();
}

class _ContactRequestsScreenState extends ConsumerState<ContactRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final Set<String> _busy = <String>{};

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _respond(ContactRequest request, {required bool accept}) async {
    if (_busy.contains(request.id)) return;
    setState(() => _busy.add(request.id));

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(contactRepositoryProvider)
          .respond(request.id, accept: accept);
      ref.invalidate(contactRequestsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? '${request.counterpartName ?? 'They'} can now message you on '
                      'WhatsApp.'
                : 'Request declined. They are not told why.',
          ),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Contact requests'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Tab>[
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: <Widget>[
            _RequestList(
              provider: contactRequestsProvider,
              emptyTitle: 'No requests yet',
              emptyMessage:
                  'When someone asks to reach you on WhatsApp, it '
                  'appears here for you to accept or decline.',
              builder: (request) => _ReceivedCard(
                request: request,
                busy: _busy.contains(request.id),
                onAccept: () => _respond(request, accept: true),
                onDecline: () => _respond(request, accept: false),
              ),
            ),
            _RequestList(
              provider: sentContactRequestsProvider,
              emptyTitle: 'No requests sent',
              emptyMessage:
                  'Requests you send from a profile appear here with '
                  'their status.',
              builder: (request) => _SentCard(request: request),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({
    required this.provider,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.builder,
  });

  final ProviderListenable<AsyncValue<ContactRequestInbox>> provider;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(ContactRequest) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(provider);

    return inbox.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(contactRequestsProvider),
      ),
      data: (data) {
        if (data.requests.isEmpty) {
          return ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.xxl),
              EmptyView(
                icon: Icons.chat_bubble_outline_rounded,
                title: emptyTitle,
                message: emptyMessage,
              ),
            ],
          );
        }
        return ContentContainer(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: data.requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => builder(data.requests[index]),
          ),
        );
      },
    );
  }
}

class _ReceivedCard extends StatelessWidget {
  const _ReceivedCard({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final ContactRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: request.isPending
              ? AppColors.badgeGoldBorder
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Avatar(
                url: request.counterpartAvatarUrl,
                initial: request.counterpartName ?? 'M',
                size: 46,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.counterpartName ?? 'A member',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${request.counterpartUsername == null ? '' : '@${request.counterpartUsername}  ·  '}'
                      '${timeAgo(request.createdAt)} ago',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          if (request.message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                request.message!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          if (request.isPending) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Accepting shares your WhatsApp number with this member only. '
              'You can block them at any time.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.request});

  final ContactRequest request;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      tileColor: AppColors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      leading: Avatar(
        url: request.counterpartAvatarUrl,
        initial: request.counterpartName ?? 'M',
        size: 42,
      ),
      title: Text(
        request.counterpartName ?? 'A member',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        'Sent ${timeAgo(request.createdAt)} ago',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: _StatusChip(status: request.status),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ContactRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground, border) = switch (status) {
      ContactRequestStatus.accepted => (
        'Accepted',
        AppColors.badgeVerifiedBg,
        AppColors.badgeVerifiedFg,
        AppColors.badgeVerifiedBorder,
      ),
      ContactRequestStatus.declined => (
        'Declined',
        AppColors.bgMuted,
        AppColors.textSecondary,
        AppColors.border,
      ),
      _ => (
        'Pending',
        AppColors.badgeGoldBg,
        AppColors.badgeGoldFg,
        AppColors.badgeGoldBorder,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.sansFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
