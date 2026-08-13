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

/// Account management and deletion.
///
/// **Store policy.** Both Google Play and the App Store require an app that
/// lets people create an account to offer account deletion from inside the app,
/// and to be honest about what deletion does. This screen is that route:
/// Settings → Account and deletion → Delete my account.
///
/// **What the backend actually does.** `DELETE /api/settings` sets
/// `isActive: false`. From that moment `requireAuth()` answers 403 on every
/// call, the profile disappears from every public surface (each read path
/// filters on `isActive`), the session is dropped, and nobody can find, message
/// or contact the member. That is a deactivation, and the copy below says so
/// rather than claiming an erasure the API does not perform.
///
/// The path to full erasure — removing rows and bucket objects — is a support
/// request, with the address stated here so the requirement is met end to end.
/// See `docs/SECURITY.md` § "Account deletion" for the operator procedure and
/// the retention window.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    final account = ref.read(myProfileProvider).valueOrNull;
    if (account == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteConfirmDialog(username: account.username),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);

    try {
      await ref.read(profileRepositoryProvider).deactivateAccount();
      // Drop the local session immediately: the cookie is now useless and
      // keeping it would leave the app in a state where every call 403s.
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your account has been closed and your profile is no longer '
            'visible.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      context.go(AppRoutes.home);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
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
                  'Delete your account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Deleting closes your account immediately. Your profile, '
                  'photos and videos stop appearing anywhere on Pinorpinor, '
                  'nobody can message or contact you, and you are signed out '
                  'on every device.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                const InlineNotice.warning(
                  message:
                      'Records we are required to keep — such as reports '
                      'made about safety incidents and credit transactions — '
                      'are retained. To have all remaining personal data '
                      'erased, contact support after deleting.',
                ),
                const SizedBox(height: AppSpacing.lg),

                OutlinedButton.icon(
                  onPressed: _deleting
                      ? null
                      : () => LegalLinks.open(context, AppConfig.contactUrl),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Request full data erasure'),
                ),
                const SizedBox(height: AppSpacing.md),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(0, AppSpacing.minTouchTarget + 4),
                  ),
                  onPressed: _deleting ? null : _deleteAccount,
                  icon: _deleting
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
                  label: const Text('Delete my account'),
                ),

                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Prefer to take a break? Turning off "Show me in discovery" '
                  'in Settings hides your profile without closing your account.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.username});

  final String username;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches =
          _controller.text.trim().toLowerCase() ==
          widget.username.toLowerCase();
      if (matches != _matches) setState(() => _matches = matches);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'This cannot be undone from the app. Type your username to '
            'confirm.',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: widget.username,
              prefixText: '@',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete'),
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
