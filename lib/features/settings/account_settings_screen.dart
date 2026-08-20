import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../profile/account_providers.dart';

/// Account management, deactivation and deletion.
///
/// **Store policy.** Both Google Play and the App Store require an app that
/// lets people create an account to offer account deletion from inside the
/// app, and to be honest about what deletion does. This screen is that route.
///
/// **Two different things, deliberately kept apart.**
///
///   * *Deactivate* (`DELETE /api/settings`) sets `isActive: false`. Every
///     read path filters on it, so the profile disappears everywhere and
///     `requireAuth()` answers 403 — but nothing is destroyed. This is the
///     right choice for someone taking a break.
///   * *Delete permanently* (`DELETE /api/account`) erases the rows and
///     removes every uploaded object from the storage bucket first. It cannot
///     be undone, and it requires the account password because a 30-day
///     session cookie is not a strong enough claim to destroy someone's
///     photographs.
///
/// The screen used to offer only the first while calling it deletion, and
/// pointed at support for erasure. The endpoint now exists, so it does the
/// real thing.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _busy = false;

  /// Reversible: hides the profile and keeps everything.
  Future<void> _deactivateAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate your account?'),
        content: const Text(
          'Your profile stops appearing anywhere and nobody can contact you. '
          'Nothing is deleted, and signing in again restores it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).deactivateAccount();
      // Drop the local session immediately: the cookie is now useless and
      // keeping it would leave the app in a state where every call 403s.
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your account is deactivated. Sign in again at any time to '
            'restore it.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      context.go(AppRoutes.home);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Irreversible: erases the rows and the bucket objects.
  Future<void> _deleteAccount() async {
    final account = ref.read(myProfileProvider).valueOrNull;
    if (account == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _DeleteConfirmDialog(username: account.username),
    );
    if (password == null) return;

    setState(() => _busy = true);

    try {
      await ref
          .read(profileRepositoryProvider)
          .deleteAccount(password: password);
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your account and all its media have been deleted.'),
          duration: Duration(seconds: 6),
        ),
      );
      context.go(AppRoutes.home);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      // A wrong password comes back as 403 with the server's own wording, so
      // the member is told which of the two things went wrong.
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: account.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          data: (data) => ContentContainer(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: <Widget>[
                _InfoRow(label: 'Username', value: '@${data.username}'),
                _InfoRow(label: 'Email', value: data.email),
                _InfoRow(
                  label: 'Verification',
                  value: data.verificationStatus.label,
                ),
                if (data.createdAt != null)
                  _InfoRow(
                    label: 'Member since',
                    value:
                        '${data.createdAt!.day}/'
                        '${data.createdAt!.month}/${data.createdAt!.year}',
                  ),

                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Take a break',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Deactivating hides your profile everywhere and stops anyone '
                  'contacting you. Nothing is deleted, and signing in again '
                  'brings it all back.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _deactivateAccount,
                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                  label: const Text('Deactivate my account'),
                ),

                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Delete your account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This permanently erases your profile and deletes every '
                  'photo and video you have uploaded from our storage. It '
                  'cannot be undone, and you will be asked for your password '
                  'to confirm.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                const InlineNotice.warning(
                  message:
                      'Records we are required to keep, such as reports made '
                      'about safety incidents and credit transactions, are '
                      'retained without your name attached.',
                ),
                const SizedBox(height: AppSpacing.lg),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(0, AppSpacing.minTouchTarget + 4),
                  ),
                  onPressed: _busy ? null : _deleteAccount,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Delete my account permanently'),
                ),

                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => LegalLinks.open(context, AppConfig.contactUrl),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Contact support'),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirms permanent deletion, and collects the password the endpoint needs.
///
/// Two separate gates, because they guard different mistakes. Typing the
/// username defends against a mis-tap: it makes the member state, in their own
/// hand, which account they mean. The password defends against someone else
/// holding an unlocked phone — a 30-day session cookie is not a strong enough
/// claim to destroy a person's photographs, and the server re-checks it.
///
/// Pops the password on confirm, or null on cancel.
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.username});

  final String username;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  bool get _canDelete =>
      _usernameController.text.trim().toLowerCase() ==
          widget.username.toLowerCase() &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'This deletes your profile and every photo and video you have '
              'uploaded. It cannot be undone.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Type your username to confirm',
                hintText: widget.username,
                prefixText: '@',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Your password',
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
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _canDelete
              ? () => Navigator.of(context).pop(_passwordController.text)
              : null,
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
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
    );
  }
}

/// Blocked members, with one-tap unblock.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(memberSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Blocked members')),
      body: SafeArea(
        child: bundle.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(memberSettingsProvider),
          ),
          data: (data) {
            if (data.blockedUsers.isEmpty) {
              return const EmptyView(
                icon: Icons.block_rounded,
                title: 'Nobody blocked',
                message:
                    'Blocking someone hides you from each other and ends '
                    'any match between you.',
              );
            }

            return ContentContainer(
              child: ListView.separated(
                itemCount: data.blockedUsers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final blocked = data.blockedUsers[index];
                  return ListTile(
                    title: Text(blocked.displayName),
                    subtitle: Text('@${blocked.username}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(safetyRepositoryProvider)
                              .unblock(blocked.id);
                          ref.invalidate(memberSettingsProvider);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${blocked.displayName} unblocked.',
                              ),
                            ),
                          );
                        } on ApiException catch (error) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
