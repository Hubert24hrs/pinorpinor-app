import 'package:flutter/material.dart';
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

/// Requests a reset link.
///
/// The backend answers success whether or not the address exists, so it cannot
/// be used to discover accounts. The copy here matches that: it says a link was
/// sent *if an account exists*, and never confirms either way.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset your password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ContentContainer(
            maxWidth: 460,
            child: _sent ? _buildSent() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const InlineNotice.success(
        message:
            'If an account exists for that address, a reset link is '
            'on its way. The link is valid for one hour.',
      ),
      const SizedBox(height: AppSpacing.xl),
      Text(
        "Didn't arrive? Check your spam folder, then request another link. "
        'Requesting a new one cancels the previous link.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.xl),
      OutlinedButton(
        onPressed: () => setState(() => _sent = false),
        child: const Text('Send another link'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextButton(
        onPressed: () => context.go(AppRoutes.login),
        child: const Text('Back to sign in'),
      ),
    ],
  );

  Widget _buildForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Enter the email address on your account and we will send a link '
          'to set a new password.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_error != null) ...<Widget>[
          InlineNotice.error(message: _error!),
          const SizedBox(height: AppSpacing.lg),
        ],
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
          ),
          validator: Validators.email,
          onFieldSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        GradientButton(
          label: 'Send reset link',
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    ),
  );
}

/// Completes a reset.
///
/// The token arrives from the emailed link, handled as a deep link
/// (`/reset-password?token=...`). It is single-use, expires in an hour and is
/// stored only as a SHA-256 hash on the server — the app passes it straight
/// through and never persists it.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _done = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tokenController.text = widget.token ?? '';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            token: _tokenController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) setState(() => _done = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ContentContainer(
            maxWidth: 460,
            child: _done
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const InlineNotice.success(
                        message:
                            'Your password has been updated. '
                            'Sign in with your new password.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      GradientButton(
                        label: 'Go to sign in',
                        onPressed: () => context.go(AppRoutes.login),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_error != null) ...<Widget>[
                          InlineNotice.error(message: _error!),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if ((widget.token ?? '').isEmpty) ...<Widget>[
                          TextFormField(
                            controller: _tokenController,
                            decoration: const InputDecoration(
                              labelText: 'Reset code',
                              helperText:
                                  'Paste the code from your reset email.',
                            ),
                            validator: (value) => Validators.required(
                              value,
                              'Paste the reset code from your email.',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          decoration: InputDecoration(
                            labelText: 'New password',
                            helperText: 'At least 8 characters.',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
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
                          ),
                          validator: (value) => Validators.confirmPassword(
                            value,
                            _passwordController.text,
                          ),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        GradientButton(
                          label: 'Update password',
                          isLoading: _submitting,
                          onPressed: _submit,
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
