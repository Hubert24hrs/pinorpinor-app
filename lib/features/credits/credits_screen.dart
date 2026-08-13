import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time_ago.dart';
import '../../data/models/credits.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/states.dart';
import '../auth/login_screen.dart';
import '../profile/account_providers.dart';

/// Credits, boosts and the ledger.
///
/// **There is no in-app purchase here, deliberately.** Pinorpinor sells credits
/// over WhatsApp and an administrator applies them; card payment is switched off
/// on the backend and the payment routes answer 503. The app reproduces that
/// arrangement rather than adding a checkout of its own.
///
/// That is also what keeps the app inside both stores' payment rules. Credits
/// unlock placement inside the app, which makes them a digital good — if the app
/// sold them, Google Play Billing and StoreKit would be mandatory. Because the
/// sale happens off-app between the member and the operator, and the app neither
/// sells nor links to a purchase flow, no billing library is required. See
/// `docs/STORE_READINESS.md` before changing any of this.
class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Credits and boosts')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () async {
            ref
              ..invalidate(walletProvider)
              ..invalidate(ledgerProvider)
              ..invalidate(boostTiersProvider);
          },
          child: wallet.when(
            loading: () => const LoadingView(),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(walletProvider),
                ),
              ],
            ),
            data: (data) => _CreditsBody(wallet: data),
          ),
        ),
      ),
    );
  }
}

class _CreditsBody extends ConsumerWidget {
  const _CreditsBody({required this.wallet});

  final Wallet wallet;

  Future<void> _activateBoost(
    BuildContext context,
    WidgetRef ref,
    BoostTier tier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activate ${tier.name}?'),
        content: Text(
          'This spends ${tier.costCredits} credits and lifts your profile in '
          'discovery for ${tier.durationHours} hours. '
          'You have ${wallet.balance} credits.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(creditsRepositoryProvider)
          .activateBoost(tier.tier);
      ref
        ..invalidate(walletProvider)
        ..invalidate(ledgerProvider)
        ..invalidate(myProfileProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Boost active. ${result.balance} credits remaining.'),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiers = ref.watch(boostTiersProvider);
    final packages = ref.watch(creditPackagesProvider);
    final ledger = ref.watch(ledgerProvider);

    return ContentContainer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          _BalanceCard(wallet: wallet),
          const SizedBox(height: AppSpacing.xl),

          if (wallet.boostActive && wallet.boostExpiresAt != null) ...<Widget>[
            InlineNotice.success(
              message:
                  'Boost tier ${wallet.boostTier} is active — it expires '
                  '${timeUntil(wallet.boostExpiresAt!)}.',
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else if (wallet.featuredActive &&
              wallet.featuredUntil != null) ...<Widget>[
            InlineNotice.info(
              message:
                  'Your profile is featured as a new member — that ends '
                  '${timeUntil(wallet.featuredUntil!)}.',
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          Text(
            'Boost your profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A boost lifts you in the discovery order for its duration. '
            'Credits are spent when you activate it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),

          tiers.when(
            loading: () =>
                const Skeleton(height: 90, borderRadius: AppRadius.lg),
            error: (_, _) => const InlineNotice.info(
              message: 'Boost options could not be loaded right now.',
            ),
            data: (list) => Column(
              children: <Widget>[
                for (final tier in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _BoostTierCard(
                      tier: tier,
                      affordable: wallet.balance >= tier.costCredits,
                      onActivate: () => _activateBoost(context, ref, tier),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          _BuyCreditsCard(
            whatsappNumber: wallet.whatsappNumber,
            packages: packages.valueOrNull ?? const <CreditPackage>[],
          ),

          if (wallet.referralCode != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            _ReferralCard(
              code: wallet.referralCode!,
              count: wallet.referralCount,
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ledger.when(
            loading: () =>
                const Skeleton(height: 120, borderRadius: AppRadius.lg),
            error: (_, _) => const SizedBox.shrink(),
            data: (entries) => entries.isEmpty
                ? Text(
                    'No credit activity yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: <Widget>[
                        for (var i = 0; i < entries.length; i++) ...<Widget>[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(
                              entries[i].reasonLabel,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              formatDateTime(entries[i].createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: Text(
                              '${entries[i].isCredit ? '+' : ''}${entries[i].amount}',
                              style: TextStyle(
                                fontFamily: AppTheme.sansFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: entries[i].isCredit
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'YOUR BALANCE',
            style: TextStyle(
              fontFamily: AppTheme.sansFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${wallet.balance}',
            style: const TextStyle(
              fontFamily: AppTheme.displayFamily,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Text(
            'credits',
            style: TextStyle(
              fontFamily: AppTheme.sansFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostTierCard extends StatelessWidget {
  const _BoostTierCard({
    required this.tier,
    required this.affordable,
    required this.onActivate,
  });

  final BoostTier tier;
  final bool affordable;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.badgeGoldBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.badgeGoldBorder),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 21,
              color: AppColors.badgeGoldFg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(tier.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${tier.costCredits} credits · ${tier.durationHours} hours',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (tier.description != null)
                  Text(
                    tier.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: affordable ? onActivate : null,
            child: Text(affordable ? 'Activate' : 'Need more'),
          ),
        ],
      ),
    );
  }
}

class _BuyCreditsCard extends StatelessWidget {
  const _BuyCreditsCard({required this.whatsappNumber, required this.packages});

  final String? whatsappNumber;
  final List<CreditPackage> packages;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Get more credits',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Credits are arranged directly with the Pinorpinor team on '
            'WhatsApp and applied to your wallet by an administrator. There is '
            'no card payment in the app.',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          if (packages.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            for (final package in packages)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${package.name} — ${package.totalCredits} credits'
                        '${package.bonusCredits > 0 ? ' (incl. ${package.bonusCredits} bonus)' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      package.priceLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
          ],

          if (whatsappNumber != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            GradientButton(
              label: 'Message us on WhatsApp',
              icon: Icons.chat_rounded,
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF25D366), Color(0xFF128C7E)],
              ),
              onPressed: () async {
                final digits = whatsappNumber!.replaceAll(RegExp(r'\D'), '');
                if (digits.isEmpty) return;
                final uri = Uri.parse(
                  'https://wa.me/$digits?text='
                  '${Uri.encodeComponent("Hi Pinorpinor, I'd like to buy credits.")}',
                );
                await LegalLinks.openExternal(uri);
              },
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: InlineNotice.info(
                message:
                    'The credits contact number is not configured yet. '
                    'Please try again shortly.',
              ),
            ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.code, required this.count});

  final String code;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.badgeRoseBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.badgeRoseBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Invite friends', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'They enter your code when joining, and you both receive bonus '
            'credits. $count ${count == 1 ? 'person has' : 'people have'} '
            'joined with yours.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.badgeRoseBorder),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: AppTheme.sansFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.badgeRoseFg,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy referral code',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral code copied.')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
