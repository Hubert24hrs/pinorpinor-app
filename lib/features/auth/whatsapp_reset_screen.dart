import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/brand.dart';
import 'login_screen.dart';

/// Resetting a password with a code sent to WhatsApp.
///
/// ## Why this exists
///
/// Registration stopped collecting email addresses on 2026-08-14, and
/// `/api/forgot-password` looks a member up by address — so every account
/// created since had **no recovery path whatsoever**. A forgotten password meant
/// a lost account and a lost profile, and members hit that in practice, which is
/// what prompted the website to build this on 2026-08-22.
///
/// Until 2026-08-25 this app was still telling people at signup that the
/// situation was unrecoverable. It was not, and this screen is the path.
///
/// ## Three steps, and the middle one is the proof
///
///   1. the number is sent to `/api/auth/whatsapp/send`,
///   2. the code comes back to `/api/auth/whatsapp/verify` and is exchanged for
///      a **proof** — an HMAC bound to the verification row and that number, so
///      it cannot be forged or moved to another number,
///   3. the proof and the new password go to
///      `/api/auth/whatsapp/reset-password`.
///
/// The proof is held in memory for the length of the flow and never stored.
///
/// ## The answer is the same either way
///
/// For a reset the send step responds identically whether or not an account
/// exists on that number. A different answer would turn this into a way of
/// asking "is this number registered here", and on an adult platform that
/// question is itself the disclosure. So the copy after step one says a code has
/// been sent **if an account exists**, and never confirms one does.
class WhatsAppResetScreen extends ConsumerStatefulWidget {
  const WhatsAppResetScreen({super.key});

  @override
  ConsumerState<WhatsAppResetScreen> createState() =>
      _WhatsAppResetScreenState();
}

enum _Step { number, code, password }

class _WhatsAppResetScreenState extends ConsumerState<WhatsAppResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.number;
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  /// Held only for the length of this flow. Never written to storage: it is a
  /// bearer credential for one password change.
  String? _proof;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    await ref
        .read(authRepositoryProvider)
        .sendWhatsAppCode(phone: _phoneController.text);
    if (mounted) setState(() => _step = _Step.code);
  });

  Future<void> _verifyCode() => _run(() async {
    final String proof = await ref
        .read(authRepositoryProvider)
        .verifyWhatsAppCode(
          phone: _phoneController.text,
          code: _codeController.text,
        );
    if (mounted) {
      setState(() {
        _proof = proof;
        _step = _Step.password;
      });
    }
  });

  Future<void> _setPassword() => _run(() async {
    final String username = await ref
        .read(authRepositoryProvider)
        .resetPasswordWithWhatsApp(
          phone: _phoneController.text,
          proof: _proof!,
          password: _passwordController.text,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password changed. Sign in as @$username.')),
    );
    // Straight to sign-in rather than signing them in here: the reset route
    // deliberately issues no session, so the new password is proved once by
    // being typed.
    context.go(AppRoutes.login);
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset with WhatsApp')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ContentContainer(
            maxWidth: 460,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const BrandMark(),
                  const SizedBox(height: AppSpacing.xl),

                  Text(switch (_step) {
                    _Step.number => 'Your WhatsApp number',
                    _Step.code => 'Enter the code',
                    _Step.password => 'Choose a new password',
                  }, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(switch (_step) {
                    _Step.number =>
                      'We will send a code to this number on WhatsApp. It '
                          'must be the number on the account.',
                    // Deliberately conditional. Confirming that an account
                    // exists on a number would make this endpoint a way of
                    // asking who is registered here.
                    _Step.code =>
                      'If an account exists on that number, a six-digit code '
                          'is on its way. It expires shortly, and five wrong '
                          'tries kill it.',
                    _Step.password =>
                      'Choose something you can remember. You will sign in '
                          'with it straight away.',
                  }, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),

                  if (_error != null) ...<Widget>[
                    InlineNotice.error(message: _error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (_step == _Step.number)
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp number',
                        hintText: '+2348012345678',
                        prefixIcon: Icon(Icons.chat_rounded, size: 20),
                        helperText: 'International format, starting with +.',
                        helperMaxLines: 2,
                      ),
                      validator: Validators.phone,
                    ),

                  if (_step == _Step.code)
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(
                        fontFamily: AppTheme.sansFamily,
                        fontSize: 22,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Six-digit code',
                        counterText: '',
                      ),
                      validator: (String? value) =>
                          (value ?? '').trim().length == 6
                          ? null
                          : 'Enter the six-digit code.',
                    ),

                  if (_step == _Step.password) ...<Widget>[
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      validator: (String? value) => Validators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),
                  GradientButton(
                    label: switch (_step) {
                      _Step.number => 'Send me a code',
                      _Step.code => 'Check the code',
                      _Step.password => 'Change my password',
                    },
                    isLoading: _submitting,
                    onPressed: switch (_step) {
                      _Step.number => _sendCode,
                      _Step.code => _verifyCode,
                      _Step.password => _setPassword,
                    },
                  ),

                  if (_step == _Step.code) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _step = _Step.number),
                      child: const Text('Use a different number'),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
