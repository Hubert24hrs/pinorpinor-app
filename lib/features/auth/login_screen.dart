import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/brand.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  /// Where to land after a successful sign-in, when the member was sent here
  /// from a protected screen.
  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
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
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      context.go(widget.redirectTo ?? AppRoutes.home);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A suspension notice survives the sign-out that produced it, so the member
    // is told why rather than silently landing back on this screen.
    final suspended = ref.watch(
      authControllerProvider.select((state) => state.suspendedReason),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Back to browsing',
                onPressed: () => context.go(AppRoutes.home),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: ContentContainer(
            maxWidth: 460,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (!Responsive.keyboardVisible(context)) ...<Widget>[
                    const Center(child: BrandMark(size: 26)),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sign in to message members, manage your profile and reply '
                    'to contact requests.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (suspended != null) ...<Widget>[
                    _Notice(
                      icon: Icons.gpp_bad_outlined,
                      background: const Color(0xFFFEF2F2),
                      border: const Color(0xFFFECACA),
                      foreground: const Color(0xFF991B1B),
                      message: suspended,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (_error != null) ...<Widget>[
                    _Notice(
                      icon: Icons.error_outline_rounded,
                      background: const Color(0xFFFEF2F2),
                      border: const Color(0xFFFECACA),
                      foreground: const Color(0xFF991B1B),
                      message: _error!,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                    ),
                    validator: Validators.email,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                    // Only "required" here: the length rule belongs to sign-up.
                    // Rejecting an existing short password would lock out a
                    // member whose account predates the current floor.
                    validator: (value) =>
                        Validators.required(value, 'Enter your password.'),
                    onFieldSubmitted: (_) => _submit(),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  GradientButton(
                    label: 'Sign in',
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Wrap rather than Row: at a large text scale, or in a
                  // language where either string is longer, a Row overflows.
                  // Wrapping moves the button onto its own line instead.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        'New to Pinorpinor?',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.join),
                        child: const Text('Create an account'),
                      ),
                    ],
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

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final IconData icon;
  final String message;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppTheme.sansFamily,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reused by other screens that need the same inline notice styling.
class InlineNotice extends StatelessWidget {
  const InlineNotice.info({super.key, required this.message})
    : icon = Icons.info_outline_rounded,
      background = const Color(0xFFF5F2EC),
      border = AppColors.border,
      foreground = AppColors.textSecondary;

  const InlineNotice.warning({super.key, required this.message})
    : icon = Icons.warning_amber_rounded,
      background = AppColors.badgeGoldBg,
      border = AppColors.badgeGoldBorder,
      foreground = AppColors.badgeGoldFg;

  const InlineNotice.success({super.key, required this.message})
    : icon = Icons.check_circle_outline_rounded,
      background = AppColors.badgeVerifiedBg,
      border = AppColors.badgeVerifiedBorder,
      foreground = AppColors.badgeVerifiedFg;

  const InlineNotice.error({super.key, required this.message})
    : icon = Icons.error_outline_rounded,
      background = const Color(0xFFFEF2F2),
      border = const Color(0xFFFECACA),
      foreground = const Color(0xFF991B1B);

  final String message;
  final IconData icon;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) => _Notice(
    icon: icon,
    message: message,
    background: background,
    border: border,
    foreground: foreground,
  );
}
