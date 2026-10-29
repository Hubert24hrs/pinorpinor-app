import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/abuse_reasons.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/repositories/safety_repository.dart';
import '../auth/auth_controller.dart';

/// The website's `/report-abuse`, as a screen.
///
/// ## Why a standalone screen, when the app already has a report sheet
///
/// The sheet needs a profile. It is reached from a member's page and reports
/// the account it was opened from, which covers the common case and misses the
/// ones that matter most:
///
///  - the profile has already been taken down, or the member blocked you, so
///    you cannot reach the page you need to report;
///  - you know the handle and nothing else, because the harassment arrived
///    somewhere other than this platform;
///  - you are reporting something about the platform itself.
///
/// `/api/report` takes `reportedUsername` as an alternative to
/// `reportedUserId` precisely so a form like this can exist, and the website's
/// Safety page links to it. Until now the app's Safety entry opened a browser,
/// so the whole reporting path left the app.
///
/// ## A session is required, and saying so early is the point
///
/// `/api/report` calls `requireAuth()` and records the reporter's id. A
/// signed-out member filling in a long, careful account of what happened and
/// then losing it to a 401 is the worst version of this screen, so the form is
/// replaced by a sign-in prompt before anything is typed.
class ReportAbuseScreen extends ConsumerStatefulWidget {
  const ReportAbuseScreen({super.key});

  @override
  ConsumerState<ReportAbuseScreen> createState() => _ReportAbuseScreenState();
}

class _ReportAbuseScreenState extends ConsumerState<ReportAbuseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _detailsController = TextEditingController();

  String? _reasonId;
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String reasonId = _reasonId ?? kDefaultAbuseReason;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(safetyRepositoryProvider)
          .report(
            reportedUsername: _usernameController.text.trim().toLowerCase(),
            reasonId: reasonId,
            details: _detailsController.text,
          );
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool signedIn = ref.watch(authControllerProvider).isSignedIn;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Report abuse')),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              Text('Report an account', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Fake profiles, stolen media, underage concerns, harassment, '
                'scams, or behaviour that was not consented to. A moderator '
                'reads every report. If you are in immediate physical danger, '
                'contact local law enforcement first.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (_sent)
                _Received(onDone: () => context.pop())
              else if (!signedIn)
                _SignInFirst(onSignIn: () => context.push(AppRoutes.login))
              else
                _buildForm(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _usernameController,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Their username',
              hintText: 'their_username',
              helperText:
                  'The handle on their profile. Leave off any @ or link.',
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Who are you reporting?';
              if (v.length > 60) return 'That is longer than any username.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          DropdownButtonFormField<String>(
            initialValue: _reasonId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'What happened?'),
            items: <DropdownMenuItem<String>>[
              for (final reason in kAbuseReasons)
                DropdownMenuItem<String>(
                  value: reason.id,
                  child: Text(reason.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _reasonId = value),
            validator: (value) =>
                value == null ? 'Choose the closest match.' : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          TextFormField(
            controller: _detailsController,
            maxLines: 6,
            minLines: 4,
            maxLength: kReportDetailsMax,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What happened',
              alignLabelWithHint: true,
              hintText:
                  'What happened, when, and anything a moderator would need '
                  'to check it. Dates and message details help.',
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.length < kReportDetailsMin) {
                return 'Please describe what happened, at least '
                    '$kReportDetailsMin characters. It is what a moderator '
                    'acts on.';
              }
              return null;
            },
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Sending…' : 'Submit report'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reports are confidential. The member is not told who reported '
            'them.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Received extends StatelessWidget {
  const _Received({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 28,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Report received', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A moderator will review it. We do not tell the member who '
            'reported them, and you will not usually hear the outcome — '
            'that is to protect you, not to dismiss it.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}

class _SignInFirst extends StatelessWidget {
  const _SignInFirst({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Sign in to report', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A report is recorded against your account so a moderator can '
            'follow it up and so the same account cannot be used to file '
            'reports in bulk. Sign in first, then come back here — we '
            'would rather ask now than lose what you have written.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
        ],
      ),
    );
  }
}
