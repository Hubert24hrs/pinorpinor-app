import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'content_widgets.dart';

/// The website's `/privacy`, as a screen.
///
/// Transcribed from `src/app/privacy/page.tsx`. Section 5 is the one that had
/// to be rewritten rather than copied, and not because the website is wrong:
/// it is a *browser* storage disclosure, listing a sign-in cookie, the age
/// acknowledgement and a collapsed-sidebar preference. Two of those three do
/// not exist here and the first is stored somewhere materially different.
///
/// What this app stores is worth a member knowing precisely, because it is
/// stronger than the browser's position, not weaker:
///
///  - the session cookie lives in the Android Keystore via
///    `flutter_secure_storage`, not on disk in the clear, which is why Dio's
///    own cookie manager is not used;
///  - the 18+ acknowledgement is a local flag, same as the website's;
///  - there is no analytics SDK, no advertising identifier and no crash
///    reporter, so there is no third party to disclose at all.
///
/// Saying "three things are stored in your browser" inside an app would be
/// false in both directions. The heading keeps the website's number and intent.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentScaffold(
      title: 'Privacy Policy',
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Privacy Policy', style: theme.textTheme.headlineMedium),
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
            ContentHeading('1. Information We Collect', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'Pinorpinor collects the username and encrypted password you '
              'register with, your WhatsApp number, and the profile details '
              'you choose to publish (bio, services, city and state, rates, '
              'and uploaded photos and short videos). Registration does not '
              'ask for an email address or a date of birth. Accounts created '
              'before 2026-08-14 may still hold an email address from the '
              'older signup form.',
            ),
            SizedBox(height: AppSpacing.lg),

            ContentHeading('2. How Information is Used', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'We use collected data strictly to render public profiles, '
              'enforce age eligibility (18+), maintain platform security, '
              'prevent fraudulent activity, and enable platform-managed '
              'inquiries.',
            ),
            SizedBox(height: AppSpacing.lg),

            ContentHeading('3. Location & Contact Privacy', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'Public profiles display general city or regional location '
              'only. Precise street addresses and live GPS coordinates are '
              'never published. Private phone numbers and email addresses are '
              'never publicly visible on profile cards.',
            ),
            SizedBox(height: AppSpacing.lg),

            ContentHeading('4. Account Data Export & Deletion', small: true),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'Members may request data export or permanent account deletion '
              'at any time from Settings. Upon deletion, profile data and '
              'media are removed from active databases, and media is deleted '
              'from storage before the rows that point at it.',
            ),
            SizedBox(height: AppSpacing.lg),

            // The website's §5 lists browser storage. This is the app's
            // equivalent; see the class comment for why it is not a copy.
            ContentHeading(
              '5. What This App Stores On Your Device',
              small: true,
            ),
            SizedBox(height: AppSpacing.xs),
            ContentBody(
              'We use no advertising identifier, no analytics and no third '
              'party trackers, and the app contains no crash reporting SDK. '
              'There is nothing to opt out of. Two things are stored on your '
              'device, and this is all of them:',
            ),
            SizedBox(height: AppSpacing.sm),
            ContentBullets(<(String?, String)>[
              (
                'Your sign-in session.',
                'Set only after you log in, and it is what keeps you signed '
                    'in. It is held in the device keystore rather than in '
                    'ordinary app storage, so another app on the phone cannot '
                    'read it. Signing out removes it.',
              ),
              (
                'Your 18+ acknowledgement,',
                'so the age notice does not reappear every time you open the '
                    'app. It records that you confirmed you are over 18, and '
                    'nothing else.',
              ),
            ]),
            ContentBody(
              'Clearing the app’s data, or uninstalling it, removes '
              'both. Neither ever leaves your device.',
            ),
          ],
        ),
      ],
    );
  }
}
