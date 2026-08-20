import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/account.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import 'account_providers.dart';

/// The member's own hub: their profile at a glance, verification status, media,
/// credits and the route into settings.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Your profile'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () async {
            ref
              ..invalidate(myProfileProvider)
              ..invalidate(walletProvider);
          },
          child: account.when(
            loading: () => const LoadingView(),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(myProfileProvider),
                ),
              ],
            ),
            data: (data) => _AccountBody(account: data),
          ),
        ),
      ),
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final completeness = account.completeness;

    return ContentContainer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Avatar(
                url: account.avatar?.url,
                initial: account.displayName,
                size: 72,
                isVerified: account.isVerified,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '@${account.username}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (account.isVerified)
                          const AppBadge.verified(dense: true)
                        else
                          const AppBadge(
                            label: 'Not verified',
                            background: AppColors.badgeGoldBg,
                            foreground: AppColors.badgeGoldFg,
                            border: AppColors.badgeGoldBorder,
                            icon: Icons.pending_outlined,
                            dense: true,
                          ),
                        if (account.profile.isRedHot)
                          const AppBadge.boosted(dense: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          if (!account.fullyVerified) ...<Widget>[
            _VerifyPrompt(account: account),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Not "awaiting review": uploads publish on arrival now, so an
          // unapproved row is one a moderator has taken down.
          if (account.hasPendingMedia) ...<Widget>[
            const InlineNotice.info(
              message:
                  'Some of your photos have been removed by a moderator and '
                  'are no longer visible to other members.',
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (completeness < 1) ...<Widget>[
            _CompletenessCard(value: completeness),
            const SizedBox(height: AppSpacing.lg),
          ],

          wallet.when(
            loading: () =>
                const Skeleton(height: 84, borderRadius: AppRadius.lg),
            error: (_, _) => const SizedBox.shrink(),
            data: (data) => _WalletCard(balance: data.balance),
          ),

          const SizedBox(height: AppSpacing.xl),
          _MenuGroup(
            items: <_MenuItem>[
              _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                subtitle: 'Bio, tagline, city, date ideas',
                onTap: () => context.push(AppRoutes.editProfile),
              ),
              if (account.canUploadMedia)
                _MenuItem(
                  icon: Icons.photo_library_outlined,
                  label: 'Photos and videos',
                  subtitle:
                      '${account.media.length} uploaded · reviewed before publishing',
                  onTap: () => context.push(AppRoutes.manageMedia),
                ),
              _MenuItem(
                icon: Icons.verified_outlined,
                label: 'Verification',
                subtitle: account.fullyVerified
                    ? 'Email and phone confirmed'
                    : 'Confirm your email and phone',
                onTap: () => context.push(AppRoutes.verification),
              ),
              _MenuItem(
                icon: Icons.chat_outlined,
                label: 'Contact requests',
                subtitle: 'Who has asked to reach you on WhatsApp',
                onTap: () => context.push(AppRoutes.contactRequests),
              ),
              _MenuItem(
                icon: Icons.bolt_outlined,
                label: 'Credits and boosts',
                subtitle: 'Move up the discovery order',
                onTap: () => context.push(AppRoutes.credits),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _MenuGroup(
            items: <_MenuItem>[
              _MenuItem(
                icon: Icons.tune_rounded,
                label: 'Discovery preferences',
                subtitle: 'Who you see, and who sees you',
                onTap: () => context.push(AppRoutes.settingsPreferences),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings and privacy',
                onTap: () => context.push(AppRoutes.settings),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your email and password to sign back in.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go(AppRoutes.home);
  }
}

class _VerifyPrompt extends StatelessWidget {
  const _VerifyPrompt({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (!account.emailVerified) 'email',
      if (account.requiresPhoneVerification && !account.phoneVerified) 'phone',
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => context.push(AppRoutes.verification),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.badgeGoldBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.badgeGoldBorder),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.verified_outlined,
              color: AppColors.badgeGoldFg,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Finish verifying your account',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Confirm your ${missing.join(' and ')} to get the verified '
                    'badge and appear in verified-only searches.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Profile completeness',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontFamily: AppTheme.sansFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.rose,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(value: value, minHeight: 7),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A fuller profile gets more genuine interest.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => context.push(AppRoutes.credits),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Credit balance',
                    style: TextStyle(
                      fontFamily: AppTheme.sansFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '$balance ${balance == 1 ? 'credit' : 'credits'}',
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(items[i].icon, size: 21),
              title: Text(
                items[i].label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: items[i].subtitle == null
                  ? null
                  : Text(
                      items[i].subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}
