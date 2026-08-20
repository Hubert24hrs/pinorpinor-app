import 'package:flutter/material.dart';

import '../routing/app_routes.dart';

/// The platform's navigation, mirrored from the website's `src/lib/navigation.ts`.
///
/// That file is the website's single definition — its desktop sidebar and its
/// mobile drawer both render from it, precisely so the two cannot drift. This
/// is the app's copy of the same list, and it exists for the same reason: the
/// app previously had five tabs and no menu, so most of the platform's surface
/// was simply unreachable from a phone.
///
/// **Keep the order and the labels identical to the website's.** A member who
/// knows where "Locations" sits on the site should find it in the same place
/// here.
///
/// ## Where each entry actually goes
///
/// Not every website page has, or should have, a native screen. Each item
/// declares how it opens, so the menu never offers a destination that silently
/// does nothing:
///
/// - [NavKind.native] — the app has a real screen for it.
/// - [NavKind.placeholder] — **the website has no feature here either.** These
///   are its own `SectionPlaceholder` stubs: Feeds, Events, Rooms, Adverts and
///   Testimonials do not exist on the platform at all. The app shows the same
///   explanation rather than pretending, and rather than hiding a menu entry
///   the member can see on the website.
/// - [NavKind.website] — static or editorial content the app does not
///   reproduce (FAQ, Safety, Reviews, Exclusive, Contact, About). Opening the
///   real page keeps one source of truth for copy that changes without a
///   release.
enum NavKind { native, placeholder, website }

@immutable
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.href,
    required this.kind,
    this.route,
    this.placeholder,
    this.authOnly = false,
    this.adminOnly = false,
  });

  final String label;
  final IconData icon;

  /// The website path. Used to open the real page for [NavKind.website], and
  /// to keep this file honestly comparable with `navigation.ts`.
  final String href;

  final NavKind kind;

  /// In-app route, for [NavKind.native].
  final String? route;

  /// Explanation shown for [NavKind.placeholder], mirroring the website's.
  final SectionPlaceholderCopy? placeholder;

  /// Hidden from signed-out visitors. The router's redirect is the real gate;
  /// this only avoids offering a link that would bounce them to sign-in.
  final bool authOnly;

  /// Moderator and up. **Always false here** — see [kNavSections].
  final bool adminOnly;
}

@immutable
class SectionPlaceholderCopy {
  const SectionPlaceholderCopy({
    required this.title,
    required this.intro,
    required this.status,
  });

  final String title;

  /// What the feature would be.
  final String intro;

  /// Why it does not exist yet. Taken verbatim from the website so the two
  /// never give a member different explanations.
  final String status;
}

@immutable
class NavSection {
  const NavSection({this.title, required this.items});

  /// Omitted for the first group, which needs no heading.
  final String? title;
  final List<NavItem> items;
}

/// The full menu, in the website's order.
///
/// **`/admin` is deliberately absent.** The website's list ends with a
/// moderation entry gated on `adminOnly`; this app ships no admin surface at
/// all, because an app that carried moderation tooling would be an app whose
/// compromise carried it too. Moderators use the website.
const List<NavSection> kNavSections = <NavSection>[
  NavSection(
    items: <NavItem>[
      NavItem(
        label: 'Home',
        icon: Icons.home_outlined,
        href: '/',
        kind: NavKind.native,
        route: AppRoutes.home,
      ),
      NavItem(
        label: 'Online Now',
        icon: Icons.local_fire_department_outlined,
        href: '/live',
        kind: NavKind.native,
        route: AppRoutes.live,
      ),
      NavItem(
        label: 'Member Discovery',
        icon: Icons.search_rounded,
        href: '/discover',
        kind: NavKind.native,
        route: AppRoutes.discover,
      ),
      NavItem(
        label: 'Exclusive',
        icon: Icons.workspace_premium_outlined,
        href: '/exclusive',
        kind: NavKind.website,
      ),
    ],
  ),
  NavSection(
    title: 'Explore',
    items: <NavItem>[
      NavItem(
        label: 'Feeds',
        icon: Icons.article_outlined,
        href: '/feeds',
        kind: NavKind.placeholder,
        placeholder: SectionPlaceholderCopy(
          title: 'Feeds',
          intro:
              'A running feed of posts from members you follow: updates, '
              'photos and availability, with likes, comments and reporting.',
          status:
              'There is no Post table in the database yet, so there is nothing '
              'this page could load. Rather than fill it with invented posts '
              'and fabricated like counts, it stays empty until the feature is '
              'actually built. Until then, member updates live on their '
              'individual profiles.',
        ),
      ),
      NavItem(
        label: 'Videos',
        icon: Icons.movie_outlined,
        href: '/videos',
        kind: NavKind.native,
        route: AppRoutes.videos,
      ),
      NavItem(
        label: 'Events',
        icon: Icons.calendar_today_outlined,
        href: '/events',
        kind: NavKind.placeholder,
        placeholder: SectionPlaceholderCopy(
          title: 'Events',
          intro:
              'Member and venue events you can search by city, filter by date '
              'and mark yourself going to.',
          status:
              'No Event model exists yet, so there are no real events to list '
              'and no real attendee counts to show. Inventing either would '
              'mean publishing a date and a place that nobody is actually '
              'holding. That is the one kind of fake data on this platform '
              'that could put someone in a room alone with a stranger.',
        ),
      ),
      NavItem(
        label: 'Rooms',
        icon: Icons.groups_outlined,
        href: '/rooms',
        kind: NavKind.placeholder,
        placeholder: SectionPlaceholderCopy(
          title: 'Rooms',
          intro:
              'Group conversations around a city or an interest, separate '
              'from one-to-one messages.',
          status:
              'Group rooms need their own model, moderation queue and '
              'membership rules, none of which exist yet. The existing '
              'Conversation model is strictly one-to-one and reusing it here '
              'would quietly put private messages into a shared thread.',
        ),
      ),
      NavItem(
        label: 'Adverts',
        icon: Icons.campaign_outlined,
        href: '/adverts',
        kind: NavKind.placeholder,
        placeholder: SectionPlaceholderCopy(
          title: 'Adverts',
          intro:
              'Paid placements from members and venues, clearly marked as '
              'advertising.',
          status:
              'No advert model or booking flow exists yet. Card payments are '
              'also suspended platform-wide, so there is currently no way to '
              'buy a placement even if this page could show one. Profile '
              'boosts, which do work, are bought with credits from your '
              'account.',
        ),
      ),
      NavItem(
        label: 'Locations',
        icon: Icons.place_outlined,
        href: '/locations',
        kind: NavKind.native,
        route: AppRoutes.locations,
      ),
    ],
  ),
  NavSection(
    title: 'Community',
    items: <NavItem>[
      NavItem(
        label: 'Reviews',
        icon: Icons.star_outline_rounded,
        href: '/reviews',
        kind: NavKind.website,
      ),
      NavItem(
        label: 'Testimonials',
        icon: Icons.format_quote_rounded,
        href: '/testimonials',
        kind: NavKind.placeholder,
        placeholder: SectionPlaceholderCopy(
          title: 'Testimonials',
          intro: 'What members say about using Pinorpinor, in their own words.',
          status:
              'No member has submitted a testimonial yet, and there is no '
              'submission flow to collect one. Testimonials are the single '
              'easiest thing on a platform to fabricate and the single least '
              'useful thing to fabricate, so this page will stay empty until '
              'real members write something we can attribute to them with '
              'their permission.',
        ),
      ),
      NavItem(
        label: 'Safety & Blacklist',
        icon: Icons.verified_user_outlined,
        href: '/safety',
        kind: NavKind.website,
      ),
      NavItem(
        label: 'FAQ',
        icon: Icons.help_outline_rounded,
        href: '/faq',
        kind: NavKind.website,
      ),
      NavItem(
        label: 'Contact & Support',
        icon: Icons.support_agent_rounded,
        href: '/contact',
        kind: NavKind.website,
      ),
    ],
  ),
  NavSection(
    title: 'My account',
    items: <NavItem>[
      NavItem(
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        href: '/messages',
        kind: NavKind.native,
        route: AppRoutes.messages,
        authOnly: true,
      ),
      NavItem(
        label: 'Notifications',
        icon: Icons.notifications_none_rounded,
        href: '/notifications',
        kind: NavKind.native,
        route: AppRoutes.notifications,
        authOnly: true,
      ),
      NavItem(
        label: 'My Profile',
        icon: Icons.person_outline_rounded,
        href: '/dashboard',
        kind: NavKind.native,
        route: AppRoutes.account,
        authOnly: true,
      ),
      NavItem(
        label: 'Saved profiles',
        icon: Icons.favorite_outline_rounded,
        href: '/dashboard',
        kind: NavKind.native,
        route: AppRoutes.favorites,
        authOnly: true,
      ),
      NavItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        href: '/settings',
        kind: NavKind.native,
        route: AppRoutes.settings,
        authOnly: true,
      ),
    ],
  ),
];

/// Filters a section's items to what this viewer may see, mirroring
/// `visibleItems` on the website.
List<NavItem> visibleNavItems(
  List<NavItem> items, {
  required bool isSignedIn,
}) {
  return <NavItem>[
    for (final NavItem item in items)
      // No admin entries exist here, so `adminOnly` never hides anything —
      // it is kept on the model only so this file stays comparable with the
      // website's.
      if (!item.adminOnly && (!item.authOnly || isSignedIn)) item,
  ];
}
