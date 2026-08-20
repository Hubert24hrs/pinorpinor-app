import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/countries.dart';
import '../../core/routing/app_routes.dart';
import '../../core/constants/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/repositories/discovery_repository.dart';
import '../../shared/widgets/profile_card.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import 'discovery_providers.dart';
import '../shell/app_drawer.dart';

/// The browse grid, reproducing `/discover` on the website.
///
/// Two visibility rules are worth stating because they are invisible in the UI
/// and enforced entirely on the server:
///   * **Anonymous callers only ever see women.** Men's profiles are private,
///     and the API hard-limits a signed-out caller regardless of any parameter.
///   * **A signed-in member is pinned to their own country.** The country
///     control below is therefore only offered to visitors — for a member it
///     would be a control that does nothing.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Prefetch a screen early so the grid does not visibly stall at the bottom.
    if (position.pixels >= position.maxScrollExtent - 600) {
      ref.read(browseProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilters() async {
    final current = ref.read(discoveryFiltersProvider);
    final pinned = ref.read(browseProvider).page.pinned;

    final updated = await showModalBottomSheet<DiscoveryFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _FilterSheet(initial: current, countryPinned: pinned),
    );

    if (updated != null) {
      ref.read(discoveryFiltersProvider.notifier).state = updated;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browseProvider);
    final filters = ref.watch(discoveryFiltersProvider);
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );

    final width = MediaQuery.sizeOf(context).width;
    final columns = Responsive.gridColumns(
      width.clamp(0, Responsive.maxContentWidth + 240),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Discover'),
        actions: <Widget>[
          // Works signed out, like the grid — /api/public/online is public.
          IconButton(
            icon: const Icon(Icons.podcasts_rounded),
            tooltip: 'Online now',
            onPressed: () => context.push(AppRoutes.live),
          ),
          // The deck needs a session; offering it signed-out would land on a
          // prompt. The grid is the surface that works for everyone.
          if (signedIn)
            IconButton(
              icon: const Icon(Icons.style_rounded),
              tooltip: 'Swipe one at a time',
              onPressed: () => context.push(AppRoutes.swipe),
            ),
          IconButton(
            onPressed: _openFilters,
            tooltip: 'Filters',
            icon: Badge.count(
              count: filters.activeCount,
              isLabelVisible: filters.activeCount > 0,
              backgroundColor: AppColors.rose,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () => ref.read(browseProvider.notifier).refresh(),
          child: Builder(
            builder: (context) {
              if (state.isLoading && state.page.profiles.isEmpty) {
                return _GridSkeleton(columns: columns);
              }
              if (state.hasError) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxxl),
                    ErrorView(
                      error: state.error!,
                      onRetry: () =>
                          ref.read(browseProvider.notifier).refresh(),
                    ),
                  ],
                );
              }
              if (state.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    EmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'No profiles match',
                      message: filters.isDefault
                          ? 'There are no public profiles in '
                                '${state.page.countryName ?? 'your country'} yet. '
                                'New members appear once their photos clear '
                                'moderation.'
                          : 'Try widening your filters.',
                      actionLabel: filters.isDefault ? null : 'Clear filters',
                      onAction: filters.isDefault
                          ? null
                          : () =>
                                ref
                                        .read(discoveryFiltersProvider.notifier)
                                        .state =
                                    DiscoveryFilters.none,
                    ),
                  ],
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: <Widget>[
                  if (state.page.countryName != null)
                    SliverToBoxAdapter(
                      child: ContentContainer(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            0,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.public_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${state.page.total} '
                                  '${state.page.total == 1 ? 'member' : 'members'} '
                                  'in ${state.page.countryName}'
                                  '${state.page.pinned ? ' · your country' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (filters.active.isNotEmpty)
                    SliverToBoxAdapter(
                      child: ContentContainer(
                        child: _ActiveFilterChips(filters: filters),
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverToBoxAdapter(
                      child: ContentContainer(
                        maxWidth: Responsive.maxContentWidth + 240,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                                childAspectRatio: 3 / 4,
                              ),
                          itemCount: state.page.profiles.length,
                          itemBuilder: (context, index) {
                            final profile = state.page.profiles[index];
                            return ProfileCard(
                              profile: profile,
                              onTap: () => context.push(
                                AppRoutes.profileFor(profile.username),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  if (state.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.xxl),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                      ),
                    ),

                  if (!signedIn) const SliverToBoxAdapter(child: _JoinPrompt()),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One chip per active filter, each with its own clear.
///
/// The count badge on the filter button says *how many* narrowings are on; it
/// cannot say *which*. Without this a member who has forgotten they set an age
/// range sees an empty grid with no visible cause, and the only way to find out
/// is to reopen the sheet.
class _ActiveFilterChips extends ConsumerWidget {
  const _ActiveFilterChips({required this.filters});

  final DiscoveryFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = filters.active;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final filter in active)
            InputChip(
              label: Text(filter.label),
              onDeleted: () => ref
                  .read(discoveryFiltersProvider.notifier)
                  .state = filter.clear(),
              deleteIcon: const Icon(Icons.close_rounded, size: 15),
              deleteButtonTooltipMessage: 'Remove ${filter.label}',
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.badgeRoseBg,
              side: const BorderSide(color: AppColors.badgeRoseBorder),
              labelStyle: const TextStyle(
                fontFamily: AppTheme.sansFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.badgeRoseFg,
              ),
            ),

          // Only worth offering once removing them one at a time is tedious.
          if (active.length > 1)
            TextButton(
              onPressed: () => ref
                  .read(discoveryFiltersProvider.notifier)
                  .state = DiscoveryFilters.none,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
              ),
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt();

  @override
  Widget build(BuildContext context) {
    return ContentContainer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: <Widget>[
            Text(
              'Want to say hello?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Browsing is open to everyone. Creating an account lets you '
              'message members and request contact.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.push(AppRoutes.join),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 3 / 4,
      ),
      itemCount: columns * 3,
      itemBuilder: (_, _) => const ProfileCardSkeleton(),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.countryPinned});

  final DiscoveryFilters initial;

  /// True for signed-in members: the backend ignores a requested country, so
  /// offering the control would be a lie.
  final bool countryPinned;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RangeValues _ageRange;
  late bool _verifiedOnly;
  late bool _availableOnly;
  late String? _countryCode;
  late final TextEditingController _cityController;
  late final Set<String> _services;
  late ActivityFilter _activity;

  @override
  void initState() {
    super.initState();
    _ageRange = RangeValues(
      widget.initial.ageMin.toDouble().clamp(18, 99),
      widget.initial.ageMax.toDouble().clamp(18, 99),
    );
    _verifiedOnly = widget.initial.verifiedOnly;
    _availableOnly = widget.initial.availableTodayOnly;
    _countryCode = widget.initial.countryCode;
    _cityController = TextEditingController(text: widget.initial.city ?? '');
    _services = widget.initial.services.toSet();
    _activity = widget.initial.activity;
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Lifts the sheet clear of the keyboard when the city field is focused.
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
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xl),

              Text('Age', style: Theme.of(context).textTheme.titleSmall),
              RangeSlider(
                values: _ageRange,
                // 18 is the floor everywhere. The server clamps it too.
                min: 18,
                max: 99,
                divisions: 81,
                labels: RangeLabels(
                  _ageRange.start.round().toString(),
                  _ageRange.end.round().toString(),
                ),
                onChanged: (values) => setState(() => _ageRange = values),
              ),
              Text(
                '${_ageRange.start.round()} – ${_ageRange.end.round()} years',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),

              TextField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'Any city',
                  prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                ),
              ),

              if (!widget.countryPinned) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: _countryCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    prefixIcon: Icon(Icons.public_rounded, size: 20),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Detect automatically'),
                    ),
                    for (final country in kCountries)
                      DropdownMenuItem<String>(
                        value: country.code,
                        child: Text(
                          country.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _countryCode = value),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                value: _verifiedOnly,
                onChanged: (value) => setState(() => _verifiedOnly = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Verified members only'),
                subtitle: Text(
                  'Members who have confirmed their email and phone.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SwitchListTile(
                value: _availableOnly,
                onChanged: (value) => setState(() => _availableOnly = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Available today'),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text('Last active', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (final option in ActivityFilter.values)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: _activity == option,
                      onSelected: (_) => setState(() => _activity = option),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              Text('Services', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                // Overlap, not containment — worth saying, because "select
                // three" reading as "must offer all three" would look like the
                // filter is broken when it returns more than expected.
                'Shows members offering any of these.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final group in servicesByGroup()) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    group.group.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final option in group.options)
                      FilterChip(
                        label: Text(option.label),
                        selected: _services.contains(option.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _services.add(option.id);
                          } else {
                            _services.remove(option.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(DiscoveryFilters.none),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final city = _cityController.text.trim();
                        Navigator.of(context).pop(
                          DiscoveryFilters(
                            city: city.isEmpty ? null : city,
                            countryCode: _countryCode,
                            ageMin: _ageRange.start.round(),
                            ageMax: _ageRange.end.round(),
                            verifiedOnly: _verifiedOnly,
                            availableTodayOnly: _availableOnly,
                            services: _services.toList(),
                            activity: _activity,
                          ),
                        );
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
