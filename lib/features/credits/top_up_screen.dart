import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/credits.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/credits.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/states.dart';
import '../auth/login_screen.dart';
import '../profile/account_providers.dart';

/// Asking for credits, with a record.
///
/// ## Why the request is written down before the chat opens
///
/// Card payment is off, so credits are sold over WhatsApp and applied by hand.
/// That conversation used to leave no trace: a member messaged the business
/// number, an admin adjusted a wallet from memory, and nothing recorded what was
/// agreed — reconciling a disputed top-up meant scrolling a chat thread.
///
/// The row is created first, and the message the member sends carries the same
/// reference the admin queue shows, so the two cannot disagree about what was
/// asked for. The reference is drawn from an alphabet with no O/0 or I/1,
/// because it gets read aloud and retyped off a phone screen.
///
/// ## Still not an in-app purchase
///
/// Nothing is charged here and no credits move. This records an intention and
/// opens WhatsApp; an admin credits the wallet once the money actually arrives.
/// That is what keeps the app outside Play Billing and StoreKit — see
/// `docs/STORE_READINESS.md` before changing it.
class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  final TextEditingController _controller = TextEditingController(
    text: '$kMinCreditPurchase',
  );

  bool _submitting = false;
  String? _error;
  CreditPurchaseResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _credits =>
      int.tryParse(_controller.text.replaceAll(RegExp(r'[\s,]'), '')) ?? 0;

  void _step(int by) {
    final int next = (_credits + by).clamp(
      kMinCreditPurchase,
      kMaxCreditPurchase,
    );
    setState(() {
      _controller.text = '$next';
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final String? problem = creditPurchaseError(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final CreditPurchaseResult result = await ref
          .read(creditsRepositoryProvider)
          .requestPurchase(_credits);

      ref.invalidate(creditPurchasesProvider);
      if (!mounted) return;
      setState(() => _result = result);

      final String? url = result.whatsappUrl;
      if (url != null) {
        // Built server-side, so the message, the stored row and the admin queue
        // can never disagree. Never rebuilt here.
        await LegalLinks.openExternal(Uri.parse(url));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<CreditPurchase>> purchases = ref.watch(
      creditPurchasesProvider,
    );
    final CreditPurchaseResult? result = _result;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Buy credits')),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              if (result != null) ...<Widget>[
                InlineNotice.success(
                  message:
                      'Request ${result.purchase.reference} recorded for '
                      '${result.purchase.credits} credits '
                      '(₦${result.purchase.amountNaira}). Send the WhatsApp '
                      'message, pay, and the credits appear here once an admin '
                      'confirms it.',
                ),
                if (result.whatsappUrl != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Open the message again'),
                    onPressed: () => unawaited(
                      LegalLinks.openExternal(Uri.parse(result.whatsappUrl!)),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],

              Text('How many credits?', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Credits are sold in ${kCreditDenomination}s at '
                '₦$kNairaPerCredit each. Opening one WhatsApp chat costs '
                '$kWhatsAppUnlockCredits.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),

              if (_error != null) ...<Widget>[
                InlineNotice.error(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],

              Row(
                children: <Widget>[
                  IconButton.outlined(
                    icon: const Icon(Icons.remove_rounded),
                    tooltip: 'Fewer credits',
                    onPressed: () => _step(-kCreditDenomination),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(
                        fontFamily: AppTheme.sansFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Credits',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.outlined(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'More credits',
                    onPressed: () => _step(kCreditDenomination),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                // The figure moves as they type, so nobody sends a message for
                // an amount they had not seen in Naira.
                _credits > 0 ? '₦${nairaForCredits(_credits)}' : '—',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),

              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final int preset in kCreditPurchasePresets)
                    ChoiceChip(
                      label: Text('$preset'),
                      selected: _credits == preset,
                      onSelected: (_) => setState(() {
                        _controller.text = '$preset';
                        _error = null;
                      }),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              GradientButton(
                label: 'Request and open WhatsApp',
                icon: Icons.chat_rounded,
                isLoading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Nothing is charged in the app. You send the message, pay the '
                'operator, and an admin adds the credits.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: AppSpacing.xxl),
              Text('Your requests', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              purchases.when(
                loading: () =>
                    const Skeleton(height: 80, borderRadius: AppRadius.lg),
                error: (Object _, StackTrace _) => const InlineNotice.info(
                  message: 'Your past requests could not be loaded right now.',
                ),
                data: (List<CreditPurchase> list) => list.isEmpty
                    ? Text('No requests yet.', style: theme.textTheme.bodySmall)
                    : Column(
                        children: <Widget>[
                          for (final CreditPurchase p in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                p.isApproved
                                    ? Icons.check_circle_rounded
                                    : Icons.hourglass_top_rounded,
                                color: p.isApproved
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                              title: Text('${p.credits} credits'),
                              subtitle: Text(
                                '${p.reference} · ${p.statusLabel}',
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: Text('₦${p.amountNaira}'),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
