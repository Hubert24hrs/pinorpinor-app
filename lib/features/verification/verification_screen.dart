import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/validators.dart';
import '../../data/models/account.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../profile/account_providers.dart';

/// Email and phone verification.
///
/// **Verified status is never set by this screen.** The app sends a code and
/// submits what the member typed; the backend decides. It also decides what
/// "fully verified" means — women must clear both email and phone, men only
/// email — and only promotes a `PENDING` account, so a rejected or suspended one
/// is not quietly reinstated by confirming a code.
///
/// Worth being honest about in the UI as well as the code: the badge proves
/// control of an address and a number. It is not an age check.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  VerificationChannel? _sendingChannel;
  VerificationChannel? _awaitingChannel;
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _confirming = false;
  String? _error;
  String? _notice;

  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    // The send endpoint allows three calls a minute; a visible cooldown means
    // the member sees a countdown rather than a 429.
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _send(VerificationChannel channel, Account account) async {
    if (channel == VerificationChannel.phone) {
      final phoneError = Validators.phone(
        _phoneController.text.isNotEmpty
            ? _phoneController.text
            : account.phone ?? '',
      );
      if (phoneError != null) {
        setState(() => _error = phoneError);
        return;
      }
    }

    setState(() {
      _sendingChannel = channel;
      _error = null;
      _notice = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendVerificationCode(
            channel,
            phone: channel == VerificationChannel.phone
                ? (_phoneController.text.isNotEmpty
                      ? _phoneController.text
                      : account.phone)
                : null,
          );
      if (!mounted) return;
      setState(() {
        _awaitingChannel = channel;
        _notice = channel == VerificationChannel.email
            ? 'We sent a 6-digit code to ${account.email}.'
            : 'We sent a 6-digit code by SMS.';
      });
      _startResendCooldown();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sendingChannel = null);
    }
  }

  Future<void> _confirm() async {
    final channel = _awaitingChannel;
    if (channel == null || _confirming) return;

    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _confirming = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .confirmVerificationCode(channel: channel, code: code);

      ref.invalidate(myProfileProvider);
      await ref.read(authControllerProvider.notifier).refresh();

      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _awaitingChannel = null;
        _notice = result.fullyVerified
            ? 'Your account is verified.'
            : '${channel.label} confirmed.';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Verification')),
      body: SafeArea(
        child: account.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          data: _buildBody,
        ),
      ),
    );
  }

  Widget _buildBody(Account account) {
    return ContentContainer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: <Widget>[
          if (account.fullyVerified) ...<Widget>[
            const InlineNotice.success(
              message:
                  'Your account is verified. You carry the verified badge '
                  'and appear in verified-only searches.',
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (_notice != null) ...<Widget>[
            InlineNotice.success(message: _notice!),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_error != null) ...<Widget>[
            InlineNotice.error(message: _error!),
            const SizedBox(height: AppSpacing.lg),
          ],

          _ChannelCard(
            title: 'Email address',
            value: account.email,
            verified: account.emailVerified,
            busy: _sendingChannel == VerificationChannel.email,
            onSend: () => _send(VerificationChannel.email, account),
            cooldown: _resendIn,
          ),

          if (account.requiresPhoneVerification) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _ChannelCard(
              title: 'Phone number',
              value: account.phone ?? 'Not set',
              verified: account.phoneVerified,
              busy: _sendingChannel == VerificationChannel.phone,
              onSend: () => _send(VerificationChannel.phone, account),
              cooldown: _resendIn,
              extra: account.phoneVerified
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'WhatsApp number',
                          hintText: account.phone ?? '+2348012345678',
                          helperText:
                              'Members never see this. It is used for '
                              'verification, and for the WhatsApp handoff once '
                              'you accept a contact request.',
                          helperMaxLines: 3,
                        ),
                      ),
                    ),
            ),
          ],

          if (_awaitingChannel != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.rose),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Enter the 6-digit code',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofocus: true,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      fontFamily: AppTheme.sansFamily,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '000000',
                    ),
                    onSubmitted: (_) => _confirm(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GradientButton(
                    label: 'Confirm',
                    isLoading: _confirming,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'What the badge means',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Verification confirms that you control this email address '
                  '${account.requiresPhoneVerification ? 'and phone number' : ''}. '
                  'It is not an age check — every member confirms they are 18 '
                  'or older at sign-up, and we act on reports of anyone who is '
                  'not.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          if (!account.fullyVerified) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Do this later'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.title,
    required this.value,
    required this.verified,
    required this.busy,
    required this.onSend,
    required this.cooldown,
    this.extra,
  });

  final String title;
  final String value;
  final bool verified;
  final bool busy;
  final VoidCallback onSend;
  final int cooldown;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: verified ? AppColors.badgeVerifiedBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (verified)
                const AppBadge.verified(dense: true)
              else
                TextButton(
                  onPressed: busy || cooldown > 0 ? null : onSend,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          cooldown > 0 ? 'Resend in ${cooldown}s' : 'Send code',
                        ),
                ),
            ],
          ),
          ?extra,
        ],
      ),
    );
  }
}
