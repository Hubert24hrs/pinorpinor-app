import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'content_widgets.dart';

/// The website's `/safety`, as a screen.
///
/// Transcribed from `src/app/safety/page.tsx`, which is the one page on the
/// platform whose copy is both current and correct: it says plainly that media
/// publishes on upload and that 18+ is a declaration rather than a check.
/// Nothing here needed correcting.
///
/// This was the most important of the five pages to bring in-app. A member who
/// needs the safety guidance is often mid-arrangement, and sending them to a
/// browser to read "tell a trusted person where you are going" is the worst
/// possible moment to hand them a page load.
///
/// The reporting panel at the bottom goes to the in-app Report Abuse screen,
/// mirroring the website's own fix: that button used to point at /contact,
/// which stored nothing and said "Message Received" regardless.
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentScaffold(
      title: 'Safety & Blacklist',
      children: <Widget>[
        const ContentHero(
          pill: 'Trust & Safety Guidelines',
          pillIcon: Icons.verified_user_rounded,
          title: 'Pinorpinor Safety Centre',
          lede:
              'Your security, dignity, and privacy are our top priorities. '
              'Learn about our profile moderation policies, age restrictions, '
              'and safe meetup best practices.',
        ),

        const ContentPillar(
          number: '01',
          title: 'Adults Only, 18+',
          tint: Color(0xFFECFDF5),
          tintFg: Color(0xFF047857),
          body:
              'Pinorpinor is for adults only and members confirm they are 18 '
              'or over when they register. That is a declaration rather than a '
              'verified check, so moderation and your reports are what '
              'actually enforce it. Anyone found to be under 18, or any '
              'profile using someone else’s images, is removed '
              'immediately and permanently.',
        ),
        const ContentPillar(
          number: '02',
          title: 'Human Profile Moderation',
          tint: Color(0xFFFFF1F5),
          tintFg: AppColors.rose,
          body:
              'Photos and videos are published as soon as they are uploaded, '
              'so profiles go live immediately. Our moderators review reported '
              'and newly uploaded media after publication and remove anything '
              'that breaks the rules. Rejected media is deleted from storage, '
              'not just hidden. If you see something that should not be here, '
              'report it and we will act on it.',
        ),
        const ContentPillar(
          number: '03',
          title: 'Location Privacy Protection',
          tint: Color(0xFFFFFBEB),
          tintFg: Color(0xFF92400E),
          body:
              'Public profiles display general city or regional location only. '
              'Precise home addresses, live GPS tracking, and phone numbers '
              'are never published.',
        ),
        const ContentPillar(
          number: '04',
          title: 'Zero Commercial Exploitation',
          tint: Color(0xFFF5F3FF),
          tintFg: Color(0xFF6D28D9),
          body:
              'Pinorpinor is a social discovery platform. Prostitution, '
              'commercial sexual services, coercion, human trafficking, and '
              'illegal services are strictly forbidden.',
        ),

        const ContentCard(
          children: <Widget>[
            ContentHeading('Safe First Meeting Guidance'),
            SizedBox(height: AppSpacing.md),
            ContentAdvice(
              title: 'Meet in Public Venues',
              body:
                  'Always schedule first meetups at busy, brightly lit public '
                  'places like restaurants, cafes, or public lounge venues.',
            ),
            ContentAdvice(
              title: 'Inform a Trusted Person',
              body:
                  'Share your date details, location, and expected return '
                  'time with a friend or family member before heading out.',
            ),
            ContentAdvice(
              title: 'Arrange Independent Transit',
              body:
                  'Drive yourself or use a reputable ride hailing service. '
                  'Never rely on someone you are meeting for the first time '
                  'to get you home.',
            ),
            ContentAdvice(
              title: 'Never Send Financial Credentials',
              body:
                  'Do not send money, banking details, or financial wire '
                  'transfers to anyone you meet online. Nobody from '
                  'Pinorpinor will ever ask for your password, your bank '
                  'details, or a verification code.',
            ),
            ContentAdvice(
              title: 'Verify on a Video Call First',
              body:
                  'Speak face to face before you agree to anything, and '
                  'settle any travel or booking cost in the chat before you '
                  'set off. Only send money once you have actually seen and '
                  'verified the person. A refusal to appear on video is the '
                  'clearest warning sign there is.',
            ),
            ContentAdvice(
              title: 'Consent Can Be Withdrawn At Any Moment',
              body:
                  'Anyone can change their mind, at any point, for any '
                  'reason, whatever was agreed beforehand. Pressuring someone '
                  'who has said no will get the account permanently removed.',
            ),
          ],
        ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'REPORT ABUSE OR SAFETY VIOLATIONS',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Reporting & Emergency Assistance',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.textInverse,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'If you encounter fake profiles, stolen media, underage '
                'concerns, harassment, or behaviour that was not consented '
                'to, please report the account immediately. For immediate '
                'physical danger, contact local law enforcement services in '
                'your jurisdiction.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textInverse.withValues(alpha: 0.72),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context.push(AppRoutes.reportAbuse),
                child: const Text('Report an account'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
