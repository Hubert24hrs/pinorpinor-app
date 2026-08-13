import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/safety_repository.dart';
import '../auth/auth_controller.dart';

/// The safety menu attached to every profile and conversation.
///
/// Both actions are backend-enforced, and neither depends on the app hiding
/// anything: a block writes a row that excludes the pair from discovery, swipes
/// and contact requests in **both** directions and unmatches them in the same
/// transaction; a report writes to the moderation queue where a human sees it.
///
/// Store policy requires user-generated-content apps to offer exactly this, in
/// app, one tap from the content. It is on the profile app bar and in the
/// conversation menu for that reason.
Future<void> showReportBlockSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required String displayName,
  VoidCallback? onBlocked,
}) async {
  final signedIn = ref.read(authControllerProvider).isSignedIn;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.error),
            title: const Text('Report this profile'),
            subtitle: Text(
              'Send it to our moderators for review.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              if (!signedIn) {
                _promptSignIn(context);
                return;
              }
              _showReportSheet(context, ref, userId, displayName);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: AppColors.error),
            title: Text('Block $displayName'),
            subtitle: Text(
              'They will not be able to see or contact you.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              if (!signedIn) {
                _promptSignIn(context);
                return;
              }
              _confirmBlock(context, ref, userId, displayName, onBlocked);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

void _promptSignIn(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Sign in to report or block members.'),
      action: SnackBarAction(
        label: 'Sign in',
        onPressed: () => context.push(AppRoutes.login),
      ),
    ),
  );
}

Future<void> _showReportSheet(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String displayName,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ReportSheet(userId: userId, displayName: displayName, ref: ref),
  );
}

Future<void> _confirmBlock(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String displayName,
  VoidCallback? onBlocked,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block $displayName?'),
      content: const Text(
        "You will not see each other in discovery, and neither of you can "
        'message or request contact. Any existing match is ended. You can '
        'unblock from Settings.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(safetyRepositoryProvider).block(userId);
    messenger.showSnackBar(
      SnackBar(content: Text('$displayName has been blocked.')),
    );
    onBlocked?.call();
  } on ApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.userId,
    required this.displayName,
    required this.ref,
  });

  final String userId;
  final String displayName;
  final WidgetRef ref;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await widget.ref
          .read(safetyRepositoryProvider)
          .report(
            reportedUserId: widget.userId,
            reason: reason,
            details: _detailsController.text,
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thank you. Our moderators will review this report.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Report ${widget.displayName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Reports are confidential. The member is not told who reported '
                'them.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),

              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(
                  children: <Widget>[
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason.label,
                          style: const TextStyle(
                            fontFamily: AppTheme.sansFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Anything else we should know? (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: _reason == null || _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
