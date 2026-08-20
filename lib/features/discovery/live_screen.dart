import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/presence.dart';
import '../../shared/widgets/profile_card.dart';
import '../../shared/widgets/states.dart';
import 'discovery_providers.dart';

/// Members who are here now — the app's counterpart of the website's `/live`.
///
/// **There is no streaming on this platform.** The page this mirrors replaced
/// one that rendered three invented streamers with fabricated viewer counts;
/// the honest version of that section is "who is actually around". Nothing here
/// implies a broadcast, and the screen must not grow a "watch" affordance for
/// something that does not exist.
///
/// Presence is a coarse bucket and never a timestamp — see [Presence] for why
/// publishing a precise last-active time to strangers is a safety problem. This
/// screen shows the bucket's own label and nothing finer.
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider);
    final strict = ref.watch(liveStrictProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Online now'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(liveProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strict
                          ? 'Members active in the last few minutes.'
                          : 'Members active recently. The badge shows how '
                                'recent.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // The strict switch narrows to the five-minute window. Off by
                  // default because on a platform this young it would usually
                  // render an empty page.
                  FilterChip(
                    label: const Text('Online only'),
                    selected: strict,
                    onSelected: (value) =>
                        ref.read(liveStrictProvider.notifier).state = value,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.rose,
                onRefresh: () async => ref.invalidate(liveProvider),
                child: live.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => ListView(
                    children: <Widget>[
                      const SizedBox(height: AppSpacing.xxxl),
                      ErrorView(
                        error: error,
                        onRetry: () => ref.invalidate(liveProvider),
                      ),
                    ],
                  ),
                  data: (page) {
                    if (page.profiles.isEmpty) {
                      return ListView(
                        children: <Widget>[
                          const SizedBox(height: AppSpacing.xxl),
                          EmptyView(
                            icon: Icons.nightlight_round,
                            title: strict
                                ? 'Nobody is online right now'
                                : 'Nobody has been active recently',
                            message: strict
                                ? 'Turn off "Online only" to see members who '
                                      'were here earlier.'
                                : 'Check back later, or browse everyone in '
                                      'Discover.',
                            actionLabel: 'Browse members',
                            onAction: () => context.go(AppRoutes.discover),
                          ),
                        ],
                      );
                    }

                    return ContentContainer(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: Responsive.of(context).isCompact
                                  ? 2
                                  : 3,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                              childAspectRatio: 0.72,
                            ),
                        itemCount: page.profiles.length,
                        itemBuilder: (context, index) {
                          final profile = page.profiles[index];
                          return ProfileCard(
                            profile: profile,
                            onTap: () => context.push(
                              AppRoutes.profileFor(profile.username),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
