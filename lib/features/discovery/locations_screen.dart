import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/states.dart';
import 'discovery_providers.dart';

/// Members by city — the app's counterpart of the website's `/locations`.
///
/// The counts come from `/api/public/locations`, which is scoped to the
/// viewer's country like everything else in discovery. Tapping a city applies
/// it as a discovery filter rather than opening a separate listing, so there is
/// one browse surface with one set of filters instead of two that can disagree.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Locations')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () async => ref.invalidate(locationsProvider),
          child: locations.when(
            loading: () => const LoadingView(),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(locationsProvider),
                ),
              ],
            ),
            data: (cities) {
              if (cities.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    EmptyView(
                      icon: Icons.place_outlined,
                      title: 'No cities to show yet',
                      message:
                          'Cities appear here once members in your country '
                          'have set a location on their profile.',
                      actionLabel: 'Browse everyone',
                      onAction: () => context.go(AppRoutes.discover),
                    ),
                  ],
                );
              }

              return ContentContainer(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: cities.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final city = cities[index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined, size: 20),
                      title: Text(city.city),
                      subtitle: city.highlight == null
                          ? null
                          : Text(city.highlight!),
                      trailing: Text(
                        '${city.count}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      onTap: () {
                        // Narrow the shared discovery filters, then hand over
                        // to the grid — one browse surface, one filter set.
                        final current = ref.read(discoveryFiltersProvider);
                        ref.read(discoveryFiltersProvider.notifier).state =
                            current.copyWith(city: city.city);
                        context.go(AppRoutes.discover);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
