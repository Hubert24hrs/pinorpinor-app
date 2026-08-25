import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/repositories/support_repository.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';

/// Contact Us — a member writes to the operator.
///
/// ## Sign-in is required, and it is a real trade
///
/// The identity comes from the session, never from the form: one that let the
/// sender type their own username would let anyone file complaints as anyone
/// else, and a moderator working the queue would have no way to tell.
///
/// The cost is that somebody who cannot sign in — the exact person most likely
/// to need support — cannot use this. That is why the menu keeps the website's
/// Contact page reachable for everyone, where the WhatsApp route is visible
/// without an account.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  String _category = kDefaultSupportCategory;
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
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
          .read(supportRepositoryProvider)
          .send(message: _messageController.text, category: _category);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool signedIn = ref.watch(
      authControllerProvider.select((AuthState a) => a.isSignedIn),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Contact support')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ContentContainer(
            maxWidth: 520,
            child: !signedIn
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const InlineNotice.info(
                        message:
                            'Messages are sent from your account, so support '
                            'knows who is writing. Sign in to use this form.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GradientButton(
                        label: 'Sign in',
                        onPressed: () => context.push(AppRoutes.login),
                      ),
                    ],
                  )
                : _sent
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const InlineNotice.success(
                        message:
                            'Message sent. Support will reply on the number on '
                            'your account.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _sent = false;
                          _messageController.clear();
                        }),
                        child: const Text('Write another'),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'What can we help with?',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        if (_error != null) ...<Widget>[
                          InlineNotice.error(message: _error!),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: <DropdownMenuItem<String>>[
                            for (final SupportCategory c in kSupportCategories)
                              DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(
                                  c.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (String? value) => setState(
                            () => _category = value ?? kDefaultSupportCategory,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        TextFormField(
                          controller: _messageController,
                          maxLines: 8,
                          maxLength: kSupportMessageMax,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Your message',
                            alignLabelWithHint: true,
                          ),
                          validator: supportMessageError,
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        GradientButton(
                          label: 'Send',
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
