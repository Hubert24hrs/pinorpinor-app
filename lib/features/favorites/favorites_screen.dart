import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/profile_card.dart';
import '../../shared/widgets/states.dart';
import 'favorites_providers.dart';

/// The member's own shortlist.
///
/// **Nobody else can see this, and the members on it are never told.** That is
/// a backend guarantee, not a UI choice — there is no endpoint that reports who
/// saved whom. The screen says so, because on a platform where women are
/// browsed by strangers, "who has bookmarked me" is the first thing a member
/// would reasonably worry about.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(ref.read(favoritesProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);

    // Keep the heart state in step with whatever pages have loaded, so a card
    // opened from here already knows it is saved.
    ref.listen(favoritesProvider, (previous, next) {
      final page = next.valueOrNull;
      if (page != null) {
        ref
            .read(savedIdsProvider.notifier)
            .seed(page.profiles.map((profile) => profile.id));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Saved')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () => ref.read(favoritesProvider.notifier).refresh(),
          child: favorites.when(
            loading: () => const LoadingView(),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(favoritesProvider),
                ),
              ],
            ),
            data: (page) {
              if (page.profiles.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    EmptyView(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Nothing saved yet',
                      message:
                          'Tap the heart on a profile to keep it here. Only '
                          'you can see this list, and the member is not told.',
                      actionLabel: 'Browse members',
                      onAction: () => context.go(AppRoutes.discover),
                    ),
                  ],
                );
              }

              return ContentContainer(
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.of(context).isCompact ? 2 : 3,
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
    );
  }
}

/// A heart that saves or unsaves a profile.
///
/// Signed-out visitors get the sign-in prompt rather than a dead control — the
/// endpoint requires auth, and a heart that silently does nothing is worse than
/// one that explains itself.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.userId,
    required this.isSignedIn,
    this.onRequiresSignIn,
  });

  final String userId;
  final bool isSignedIn;
  final VoidCallback? onRequiresSignIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedIdsProvider).contains(userId);

    return IconButton(
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: saved ? AppColors.rose : null,
      ),
      tooltip: saved ? 'Remove from saved' : 'Save this profile',
      onPressed: () async {
        if (!isSignedIn) {
          onRequiresSignIn?.call();
          return;
        }
        try {
          await ref.read(savedIdsProvider.notifier).toggle(userId);
        } on Exception {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update your saved list.')),
          );
        }
      },
    );
  }
}
