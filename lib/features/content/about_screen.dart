import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'content_widgets.dart';

/// The website's `/about`, as a screen.
///
/// Copy transcribed from `src/app/about/page.tsx`. **One claim is changed, on
/// purpose**, and the change is the honest one rather than the faithful one:
///
/// The website's fourth pillar reads "Human Content Moderation: All uploaded
/// photos and videos are independently verified for quality and compliance",
/// and its Terms §2 says review happens "prior to public display". Neither is
/// true. Media has published on insert since 2026-08-14 (`isApproved: true`),
/// and moderation is reactive — which the website's own Safety page and FAQ
/// both state correctly. The three pages contradict each other.
///
/// Reproducing "verified before display" inside a shipped app would be telling
/// members their safety rests on a review that does not happen, on the one
/// platform surface where that matters most. So this screen states what the
/// platform actually does, in the website's register. The website needs the
/// same correction; that is the other repository's change to make.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentScaffold(
      title: 'About',
      children: <Widget>[
        ContentHero(
          pill: 'About Pinorpinor',
          pillIcon: Icons.auto_awesome_rounded,
          title: 'Our Vision & Platform Mission',
          lede:
              'Pinorpinor is an original, premium social discovery and meetup '
              'platform created to celebrate authentic profile presentation '
              'and local connections of genuine quality.',
        ),
        ContentCard(
          children: <Widget>[
            ContentHeading('Redefining Social Discovery'),
            SizedBox(height: AppSpacing.sm),
            ContentBody(
              'Unlike generic swipe applications that lock all content behind '
              'a login wall, Pinorpinor offers open public profile discovery '
              'for approved adult members. Visitors can browse public profile '
              'photos, short profile videos, interests, and preferred date '
              'activities before choosing to connect.',
            ),
            SizedBox(height: AppSpacing.lg),
            ContentHeading('Key Platform Pillars', small: true),
            SizedBox(height: AppSpacing.sm),
            ContentBullets(<(String?, String)>[
              (
                'Member Profile Submission:',
                'Verified adults (18+) create and manage public profiles on '
                    'their own terms.',
              ),
              // Corrected against the website. See the class comment.
              (
                'Content Moderation:',
                'Photos and videos publish as soon as they are uploaded, so a '
                    'profile goes live immediately. Moderators review media '
                    'after publication and remove anything that breaks the '
                    'rules, and removed media is deleted from storage rather '
                    'than hidden.',
              ),
              (
                'Privacy First:',
                'Location is shown as a general city or region only. Phone '
                    'numbers are never published, and a WhatsApp chat opens '
                    'through a server-side redirect that never prints one.',
              ),
              (
                'Adults Only, 18+:',
                'Members confirm they are 18 or over when they register. That '
                    'is a declaration rather than a verified check, so '
                    'moderation and member reports are what enforce it.',
              ),
            ]),
          ],
        ),
      ],
    );
  }
}
