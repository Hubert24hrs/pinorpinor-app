import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/enums.dart';
import '../../data/models/settings.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/states.dart';
import '../profile/account_providers.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(memberSettingsProvider);
    final version = ref.watch(_appVersionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Settings and privacy')),
      body: SafeArea(
        child: bundle.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(memberSettingsProvider),
          ),
          data: (data) => ContentContainer(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              children: <Widget>[
                const _SectionLabel(text: 'Notifications'),
                _NotificationToggles(settings: data.settings),

                const _SectionLabel(text: 'Discovery'),
                _DiscoveryToggles(settings: data.settings),

                const _SectionLabel(text: 'Safety'),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('Blocked members'),
                  subtitle: Text(
                    data.blockedUsers.isEmpty
                        ? 'Nobody blocked'
                        : '${data.blockedUsers.length} blocked',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => context.push(AppRoutes.settingsBlocked),
                ),
                ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: const Text('Safety guidance'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => LegalLinks.open(context, AppConfig.safetyUrl),
                ),

                const _SectionLabel(text: 'Legal'),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      LegalLinks.open(context, AppConfig.privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text('Terms of use'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => LegalLinks.open(context, AppConfig.termsUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('Contact support'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => LegalLinks.open(context, AppConfig.contactUrl),
                ),

                const _SectionLabel(text: 'Account'),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Account and deletion'),
                  subtitle: Text(
                    'Deactivate or delete your Pinorpinor account',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => context.push(AppRoutes.settingsAccount),
                ),

                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    'Pinorpinor  ·  ${version.valueOrNull ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationToggles extends ConsumerStatefulWidget {
  const _NotificationToggles({required this.settings});

  final MemberSettings settings;

  @override
  ConsumerState<_NotificationToggles> createState() =>
      _NotificationTogglesState();
}

class _NotificationTogglesState extends ConsumerState<_NotificationToggles> {
  late MemberSettings _local = widget.settings;
  bool _saving = false;

  Future<void> _save(MemberSettings next) async {
    // Optimistic: the switch moves at once, and reverts if the write fails.
    final previous = _local;
    setState(() {
      _local = next;
      _saving = true;
    });

    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .updateSettings(next);
      if (mounted) setState(() => _local = saved);
      ref.invalidate(memberSettingsProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _local = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SwitchListTile(
          value: _local.notifyOnMatch,
          onChanged: _saving
              ? null
              : (value) => _save(_local.copyWith(notifyOnMatch: value)),
          title: const Text('New matches'),
        ),
        SwitchListTile(
          value: _local.notifyOnMessage,
          onChanged: _saving
              ? null
              : (value) => _save(_local.copyWith(notifyOnMessage: value)),
          title: const Text('New messages'),
        ),
        SwitchListTile(
          value: _local.notifyOnLike,
          onChanged: _saving
              ? null
              : (value) => _save(_local.copyWith(notifyOnLike: value)),
          title: const Text('Someone likes you'),
        ),
        SwitchListTile(
          value: _local.notifyOnDateProposal,
          onChanged: _saving
              ? null
              : (value) => _save(_local.copyWith(notifyOnDateProposal: value)),
          title: const Text('Date proposals'),
        ),
      ],
    );
  }
}

class _DiscoveryToggles extends ConsumerStatefulWidget {
  const _DiscoveryToggles({required this.settings});

  final MemberSettings settings;

  @override
  ConsumerState<_DiscoveryToggles> createState() => _DiscoveryTogglesState();
}

class _DiscoveryTogglesState extends ConsumerState<_DiscoveryToggles> {
  late MemberSettings _local = widget.settings;
  bool _saving = false;

  Future<void> _save(MemberSettings next) async {
    final previous = _local;
    setState(() {
      _local = next;
      _saving = true;
    });
    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .updateSettings(next);
      if (mounted) setState(() => _local = saved);
      ref
        ..invalidate(memberSettingsProvider)
        ..invalidate(myProfileProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _local = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SwitchListTile(
          value: _local.showInDiscovery,
          onChanged: _saving
              ? null
              : (value) => _save(_local.copyWith(showInDiscovery: value)),
          title: const Text('Show me in discovery'),
          subtitle: Text(
            'Turning this off hides your profile from the discovery deck and '
            'the browse grid. Existing conversations are unaffected.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.tune_rounded),
          title: const Text('Who you want to see'),
          subtitle: Text(
            'Men, women or everyone',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => context.push(AppRoutes.settingsPreferences),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: AppTheme.sansFamily,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: AppColors.textMuted,
      ),
    ),
  );
}

/// Who the member wants to see. Read from the database on every discovery
/// query, so this is the only thing that changes what the deck returns.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Discovery preferences')),
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
                Text('Show me', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _InterestedInSelector(current: data.effectiveInterestedIn),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.bgMuted,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text(
                    'Discovery is also scoped to your country, which comes from '
                    'your profile. Change your country in Edit profile to see '
                    'members elsewhere.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestedInSelector extends ConsumerStatefulWidget {
  const _InterestedInSelector({required this.current});

  final InterestedIn current;

  @override
  ConsumerState<_InterestedInSelector> createState() =>
      _InterestedInSelectorState();
}

class _InterestedInSelectorState extends ConsumerState<_InterestedInSelector> {
  bool _saving = false;
  InterestedIn? _pending;

  @override
  Widget build(BuildContext context) {
    final selected = _pending ?? widget.current;

    return RadioGroup<InterestedIn>(
      groupValue: selected,
      // RadioGroup requires a non-null callback, so the guard lives inside it
      // rather than disabling the whole group while a save is in flight.
      onChanged: (value) {
        if (_saving || value == null) return;
        _select(value);
      },
      child: Column(
        children: <Widget>[
          for (final option in InterestedIn.values)
            RadioListTile<InterestedIn>(
              value: option,
              title: Text(option.label),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Future<void> _select(InterestedIn value) async {
    setState(() {
      _saving = true;
      _pending = value;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileRepositoryProvider).updatePreferences(value);
      ref.invalidate(myProfileProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Preference updated.')),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _pending = null);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
