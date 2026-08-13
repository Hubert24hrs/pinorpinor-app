import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_providers.dart';

/// The five-destination shell.
///
/// Phones get a bottom navigation bar; tablets and iPads get a side rail
/// instead, because a bottom bar stretched across a 12-inch display puts the
/// controls a long way from the thumbs and wastes the width. Both drive the same
/// `StatefulNavigationShell`, so each tab keeps its own history either way.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_Destination>[
    _Destination(
      route: AppRoutes.home,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _Destination(
      route: AppRoutes.discover,
      label: 'Discover',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
    ),
    _Destination(
      route: AppRoutes.messages,
      label: 'Messages',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      requiresAuth: true,
    ),
    _Destination(
      route: AppRoutes.notifications,
      label: 'Alerts',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
      requiresAuth: true,
    ),
    _Destination(
      route: AppRoutes.account,
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      requiresAuth: true,
    ),
  ];

  void _onSelect(BuildContext context, WidgetRef ref, int index) {
    final destination = _destinations[index];
    final signedIn = ref.read(authControllerProvider).isSignedIn;

    // A tab that needs an account routes to sign-in rather than opening an
    // empty screen. The backend would refuse the calls anyway; this just makes
    // the reason obvious.
    if (destination.requiresAuth && !signedIn) {
      context.push(
        '${AppRoutes.login}?redirect=${Uri.encodeComponent(destination.route)}',
      );
      return;
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formFactor = Responsive.of(context);
    final unread = ref.watch(unreadBadgeProvider);

    if (formFactor.isTablet) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) =>
                    _onSelect(context, ref, index),
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.bgSecondary,
                indicatorColor: AppColors.badgeRoseBg,
                selectedIconTheme: const IconThemeData(color: AppColors.rose),
                unselectedIconTheme: const IconThemeData(
                  color: AppColors.textMuted,
                ),
                selectedLabelTextStyle: const TextStyle(
                  fontFamily: AppTheme.sansFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.rose,
                ),
                unselectedLabelTextStyle: const TextStyle(
                  fontFamily: AppTheme.sansFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
                destinations: <NavigationRailDestination>[
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: _badged(destination, unread, selected: false),
                      selectedIcon: _badged(
                        destination,
                        unread,
                        selected: true,
                      ),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onSelect(context, ref, index),
        destinations: <NavigationDestination>[
          for (final destination in _destinations)
            NavigationDestination(
              icon: _badged(destination, unread, selected: false),
              selectedIcon: _badged(destination, unread, selected: true),
              label: destination.label,
              tooltip: destination.label,
            ),
        ],
      ),
    );
  }

  Widget _badged(
    _Destination destination,
    UnreadCounts unread, {
    required bool selected,
  }) {
    final icon = Icon(selected ? destination.selectedIcon : destination.icon);
    final count = switch (destination.route) {
      AppRoutes.messages => unread.messages,
      AppRoutes.notifications => unread.notifications,
      _ => 0,
    };
    if (count <= 0) return icon;

    return Badge.count(
      count: count,
      backgroundColor: AppColors.rose,
      textColor: Colors.white,
      child: icon,
    );
  }
}

class _Destination {
  const _Destination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.requiresAuth = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool requiresAuth;
}
