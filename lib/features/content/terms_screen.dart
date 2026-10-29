import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'content_widgets.dart';

/// The website's `/terms`, as a screen.
///
/// Transcribed from `src/app/terms/page.tsx`. **Section 2's last sentence is
/// corrected**, for the same reason as the About screen's moderation pillar:
/// the website says "All submitted media undergoes human moderation review
/// prior to public display", and it does not. Media publishes on insert
/// (`isApproved: true`, since 2026-08-14) and review is reactive — which the
/// Safety page and the FAQ both state correctly, so the website contradicts
/// itself across three pages.
///
/// This one matters more than the About wording, because Terms of Service is
/// the document a member is held to and the one an app store reads. Shipping a
/// promise of pre-publication review that the platform does not perform would
/// be a false claim in the one place it is least defensible.
///
/// The correction is narrow: the review happens, after publication, and
/// removal is real. Nothing else in the section changes.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentScaffold(
      title: 'Terms of Service',
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Terms of Service', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Last updated: August 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const ContentCard(
          children: <Widget>[
            ContentHeading('1. Eligibility', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'Pinorpinor is an 18+ platform. By accessing or creating an '
              'account, you confirm you are at least 18 years old. Any '
              'attempt to circumvent age verification constitutes a serious '
              'violation and will result in permanent account termination and '
              'potential legal referral.',
            ),
            SizedBox(height: AppSpacing.lg),

            ContentHeading('2. Profile Submission Standards', small: true),
            SizedBox(height: AppSpacing.xs),
            // Corrected: the website promises review "prior to public
            // display". See the class comment.
            ContentBody(
              'Profiles submitted to Pinorpinor must be authentic. '
              'Impersonation, use of others’ photos without consent, or '
              'submission of AI-generated fictitious profiles are strictly '
              'forbidden. Submitted media publishes immediately and is '
              'reviewed by moderators after publication; anything breaking '
              'these terms is removed and deleted from storage.',
            ),
            SizedBox(height: AppSpacing.lg),

            ContentHeading('3. Prohibited Conduct', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'The following activities are strictly prohibited on '
              'Pinorpinor:',
            ),
            SizedBox(height: AppSpacing.sm),
            ContentBullets(<(String?, String)>[
              (
                null,
                'Solicitation of commercial sexual services, escort '
                    'arrangements, or prostitution',
              ),
              (
                null,
                'Human trafficking, coercion, or exploitation of any person',
              ),
              (
                null,
                'Distribution of explicit sexual content without documented '
                    'consent',
              ),
              (
                null,
                'Harassment, threats, blackmail, or abusive communications',
              ),
              (
                null,
                'Fraudulent identity, financial scams, or romance fraud '
                    'targeting members',
              ),
              (
                null,
                'Creation of profiles for individuals under 18 years of age',
              ),
            ]),
            SizedBox(height: AppSpacing.md),

            ContentHeading('4. Content Moderation', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'Pinorpinor reserves the right to reject, remove, or modify any '
              'submitted profile, photo, video, or bio that violates these '
              'Terms of Service without prior notice. Accounts in serious '
              'breach will be permanently suspended.',
            ),
            SizedBox(height: AppSpacing.lg),

            ContentHeading('5. Termination', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'We reserve the right to terminate access to any account at our '
              'discretion if platform rules or community standards are '
              'violated. Members may delete their accounts at any time from '
              'Settings.',
            ),
            SizedBox(height: AppSpacing.lg),

            ContentHeading('6. Governing Law', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'These Terms are governed by applicable laws. Disputes shall be '
              'resolved through good-faith negotiation before legal action is '
              'pursued.',
            ),
          ],
        ),
      ],
    );
  }
}
