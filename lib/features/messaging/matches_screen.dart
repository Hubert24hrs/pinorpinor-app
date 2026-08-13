import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time_ago.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import 'messaging_providers.dart';

/// Active matches — pairs who liked each other. Each one already has a
/// conversation; the backend creates it in the same transaction as the match.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Your matches')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () async => ref.invalidate(matchesProvider),
          child: matches.when(
            loading: () => const LoadingView(),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(matchesProvider),
                ),
              ],
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    EmptyView(
                      icon: Icons.favorite_border_rounded,
                      title: 'No matches yet',
                      message:
                          'A match happens when you and another member '
                          'both like each other.',
                      actionLabel: 'Start discovering',
                      onAction: () => context.go(AppRoutes.discover),
                    ),
                  ],
                );
              }

              return ContentContainer(
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.of(context).isCompact ? 2 : 3,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final match = items[index];
                    final partner = match.partner;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => context.push(
                        AppRoutes.conversationFor(match.conversationId),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            child: ProfileImage(
                              url: partner?.avatarUrl,
                              fallbackInitial: partner?.displayName,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            partner?.displayName ?? 'Member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            'Matched ${timeAgo(match.createdAt)} ago',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
