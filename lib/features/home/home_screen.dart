import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/profile.dart';
import '../../data/models/settings.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/profile_card.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import '../discovery/discovery_providers.dart';
import '../shell/app_drawer.dart';

/// The landing screen, reproducing the website's homepage in mobile form:
/// a hero, the Face of the Day, a rail of new and boosted members, and the
/// city list — all of it browsable without an account, exactly as the website
/// intends.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final spotlight = ref.watch(spotlightProvider);
    final ladies = ref.watch(ladiesProvider);
    final locations = ref.watch(locationsProvider);

    return Scaffold(
      // The SliverAppBar below picks up the hamburger from this automatically.
      drawer: const AppDrawer(),
      backgroundColor: AppColors.bgPrimary,
      body: RefreshIndicator(
        color: AppColors.rose,
        onRefresh: () async {
          ref.invalidate(spotlightProvider);
          ref.invalidate(ladiesProvider);
          ref.invalidate(locationsProvider);
          await Future.wait<void>(<Future<void>>[
            ref.read(spotlightProvider.future).then((_) {}, onError: (_) {}),
            ref.read(ladiesProvider.future).then((_) {}, onError: (_) {}),
          ]);
        },
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.bgSecondary,
              title: const BrandMark(size: 19),
              titleSpacing: AppSpacing.lg,
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search profiles',
                  onPressed: () => context.go(AppRoutes.discover),
                ),
                if (!auth.isSignedIn)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.login),
                      child: const Text('Sign in'),
                    ),
                  ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),

            SliverToBoxAdapter(
              child: ContentContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Hero(isSignedIn: auth.isSignedIn),
                    const SizedBox(height: AppSpacing.xl),

                    spotlight.when(
                      loading: () => const _SpotlightSkeleton(),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (data) => data.faceOfTheDay == null
                          ? const SizedBox.shrink()
                          : _FaceOfTheDay(
                              profile: data.faceOfTheDay!,
                              countryName: data.countryName,
                            ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeader(
                      title: 'New and featured',
                      action: 'See all',
                      onAction: () => context.go(AppRoutes.discover),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: ladies.when(
                loading: () => const _RailSkeleton(),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: ErrorView(
                    error: error,
                    compact: true,
                    onRetry: () => ref.invalidate(ladiesProvider),
                  ),
                ),
                data: (page) => page.profiles.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xl,
                        ),
                        child: EmptyView(
                          icon: Icons.people_outline_rounded,
                          title: 'No profiles here yet',
                          message:
                              'New members appear as soon as their photos '
                              'clear moderation.',
                        ),
                      )
                    : _ProfileRail(page: page),
              ),
            ),

            SliverToBoxAdapter(
              child: ContentContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    const _SectionHeader(title: 'Browse by city'),
                    const SizedBox(height: AppSpacing.md),
                    locations.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            Skeleton(width: 96, height: 34, borderRadius: 999),
                            Skeleton(width: 78, height: 34, borderRadius: 999),
                            Skeleton(width: 110, height: 34, borderRadius: 999),
                            Skeleton(width: 88, height: 34, borderRadius: 999),
                          ],
                        ),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (cities) => _CityChips(cities: cities),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const _SafetyCard(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.isSignedIn});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.verified_user_rounded,
                  size: 12,
                  color: AppColors.gold,
                ),
                SizedBox(width: 5),
                Text(
                  '18+ · MODERATED · MEMBER CONSENT',
                  style: TextStyle(
                    fontFamily: AppTheme.sansFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Meet remarkable people,\non your terms.',
            style: TextStyle(
              fontFamily: AppTheme.displayFamily,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Browse verified profiles freely. Contact happens only when a '
            'member says yes.',
            style: TextStyle(
              fontFamily: AppTheme.sansFamily,
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: GradientButton(
                  label: isSignedIn ? 'Start discovering' : 'Create an account',
                  icon: isSignedIn
                      ? Icons.explore_rounded
                      : Icons.auto_awesome_rounded,
                  onPressed: () => context.go(
                    isSignedIn ? AppRoutes.discover : AppRoutes.join,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaceOfTheDay extends StatelessWidget {
  const _FaceOfTheDay({required this.profile, this.countryName});

  final SpotlightProfile profile;
  final String? countryName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => context.push(AppRoutes.profileFor(profile.username)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.badgeGoldBorder),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: <Widget>[
              ProfileImage(
                url: profile.imageUrl,
                width: 76,
                height: 92,
                fallbackInitial: profile.displayName,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          countryName == null
                              ? 'FACE OF THE DAY'
                              : 'FACE OF THE DAY · ${countryName!.toUpperCase()}',
                          style: const TextStyle(
                            fontFamily: AppTheme.sansFamily,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.badgeGoldFg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (profile.tagline != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        profile.tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (profile.city != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      AppBadge.location(label: profile.city!, dense: true),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRail extends StatelessWidget {
  const _ProfileRail({required this.page});

  final ProfilePage page;

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.of(context).isCompact ? 156.0 : 190.0;

    return SizedBox(
      height: cardWidth / (3 / 4) + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: page.profiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final profile = page.profiles[index];
          return SizedBox(
            width: cardWidth,
            child: ProfileCard(
              profile: profile,
              onTap: () => context.push(AppRoutes.profileFor(profile.username)),
            ),
          );
        },
      ),
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.of(context).isCompact ? 156.0 : 190.0;
    return SizedBox(
      height: cardWidth / (3 / 4) + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, _) =>
            SizedBox(width: cardWidth, child: const ProfileCardSkeleton()),
      ),
    );
  }
}

class _SpotlightSkeleton extends StatelessWidget {
  const _SpotlightSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Skeleton(height: 116, borderRadius: AppRadius.xl),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (action != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class _CityChips extends ConsumerWidget {
  const _CityChips({required this.cities});

  final List<LocationCount> cities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cities.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final city in cities)
            ActionChip(
              avatar: const Icon(
                Icons.place_rounded,
                size: 14,
                color: AppColors.rose,
              ),
              label: Text('${city.city} · ${city.count}'),
              onPressed: () {
                ref
                    .read(discoveryFiltersProvider.notifier)
                    .update((filters) => filters.copyWith(city: city.city));
                context.go(AppRoutes.discover);
              },
            ),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.badgeVerifiedBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.badgeVerifiedBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.shield_rounded,
            size: 20,
            color: AppColors.badgeVerifiedFg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'How Pinorpinor keeps contact consensual',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Our moderators review photos and videos, and remove '
                  'anything that breaks the rules. A member\'s phone number is never published — you '
                  'ask, and they decide. You can block or report anyone at any '
                  'time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
