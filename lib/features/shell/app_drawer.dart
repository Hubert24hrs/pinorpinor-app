import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/navigation.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import 'section_placeholder_screen.dart';

/// The platform menu, rendered from [kNavSections].
///
/// The app used to expose five tabs and nothing else, so most of what the
/// website offers — Online Now, Videos, Locations, Reviews, FAQ, Safety — was
/// simply unreachable from a phone. This is the drawer the website's own mobile
/// layout has, built from the same definition and in the same order.
///
/// Every entry leads somewhere real. Items the app implements natively push an
/// app route; items the website has not built show the same explanation it
/// shows; static content opens the real page. Nothing here is decorative.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isSignedIn = auth.isSignedIn;
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: AppColors.bgPrimary,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(child: BrandMark()),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            if (isSignedIn && auth.session != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.account_circle_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '@${auth.session!.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: AppSpacing.lg),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final NavSection section in kNavSections)
                    ..._buildSection(context, ref, section, isSignedIn, theme),

                  if (!isSignedIn) ...<Widget>[
                    const Divider(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: GradientButton(
                        label: 'Sign in',
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push(AppRoutes.login);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSection(
    BuildContext context,
    WidgetRef ref,
    NavSection section,
    bool isSignedIn,
    ThemeData theme,
  ) {
    final items = visibleNavItems(section.items, isSignedIn: isSignedIn);
    if (items.isEmpty) return const <Widget>[];

    return <Widget>[
      if (section.title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            section.title!.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
      for (final NavItem item in items)
        ListTile(
          leading: Icon(item.icon, size: 22),
          title: Text(item.label),
          // Marked so a member can tell, before tapping, which entries lead to
          // content that lives on the website rather than in the app.
          trailing: item.kind == NavKind.website
              ? const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                )
              : null,
          minLeadingWidth: 24,
          onTap: () => _open(context, item),
        ),
    ];
  }

  void _open(BuildContext context, NavItem item) {
    Navigator.of(context).pop();

    switch (item.kind) {
      case NavKind.native:
        final route = item.route;
        if (route == null) return;
        // The five shell tabs are `go` destinations; everything else is pushed
        // so the back gesture returns to where the member opened the menu.
        if (_shellRoutes.contains(route)) {
          context.go(route);
        } else {
          unawaited(context.push(route));
        }

      case NavKind.placeholder:
        final copy = item.placeholder;
        if (copy == null) return;
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SectionPlaceholderScreen(copy: copy),
            ),
          ),
        );

      case NavKind.website:
        unawaited(
          LegalLinks.open(context, '${AppConfig.apiOrigin}${item.href}'),
        );
    }
  }

  /// Destinations owned by the bottom bar's `StatefulShellRoute`. Pushing one
  /// of these would stack a second copy on top of the shell instead of
  /// switching tabs.
  static const Set<String> _shellRoutes = <String>{
    AppRoutes.home,
    AppRoutes.discover,
    AppRoutes.messages,
    AppRoutes.notifications,
    AppRoutes.account,
  };
}
