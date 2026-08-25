import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/brand.dart';
import '../auth/login_screen.dart';

/// Changing your own password — including when the platform is making you.
///
/// ## The state this screen exists for
///
/// An admin can reset a member's password without learning it (2026-08-22). The
/// member is handed a temporary one and their account is flagged
/// `mustChangePassword`, and while that flag holds **`requireAuth()` refuses
/// everything else on the platform**. Discovery, messages, the profile — all of
/// it answers with the same refusal.
///
/// So an app without this screen leaves that member staring at failures with no
/// way through, which is worse than the problem the admin reset was solving.
/// This route is the one thing allowed in that state, and the app checks for it
/// rather than waiting to be told.
///
/// ## The current password is required even when the change is forced
///
/// That is the point of the design, not an oversight: after an admin issues a
/// temporary password, the only person who can complete this is whoever was
/// given it. Skipping the check "because we already forced a change" would let
/// any hijacked session set a new password and lock the real owner out.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
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
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );

      ref.invalidate(passwordStatusProvider);
      // Lifts the router's block. Set centrally when any call answered
      // PASSWORD_CHANGE_REQUIRED, cleared here because this is the one action
      // that resolves it.
      ref.read(passwordChangeRequiredProvider.notifier).state = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been changed.')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PasswordStatus> status = ref.watch(passwordStatusProvider);
    final bool forced = status.valueOrNull?.mustChange ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        // No back arrow while the change is compulsory: there is nothing else
        // the member can reach until it is done, so offering a way out would
        // send them to a screen that only answers refusals.
        automaticallyImplyLeading: !forced,
      ),
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
                  if (forced) ...<Widget>[
                    const InlineNotice.warning(
                      message:
                          'Your password was reset by support. Choose a new '
                          'one to carry on — nothing else works until you do.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (_error != null) ...<Widget>[
                    InlineNotice.error(message: _error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  TextFormField(
                    controller: _currentController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: forced
                          ? 'The temporary password support gave you'
                          : 'Current password',
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
                        tooltip: _obscure ? 'Show' : 'Hide',
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (String? value) => (value ?? '').isEmpty
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  TextFormField(
                    controller: _newController,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
                      helperText: 'At least 8 characters.',
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
                    validator: (String? value) =>
                        Validators.confirmPassword(value, _newController.text),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  GradientButton(
                    label: 'Change my password',
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

/// Whether the signed-in member is sitting on a temporary password.
///
/// Read once per session rather than polled: the flag only changes when an admin
/// resets a password, at which point the member's next authenticated call fails
/// anyway and the app re-reads.
final passwordStatusProvider = FutureProvider<PasswordStatus>((ref) async {
  return ref.watch(profileRepositoryProvider).passwordStatus();
});
