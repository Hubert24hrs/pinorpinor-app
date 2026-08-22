import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/live_sessions.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/brand.dart';

/// The app's answer to the website's `/app` page — the "Get the App" menu entry.
///
/// ## Why this screen exists at all, inside the app
///
/// The website's menu offers "Get the App", and this app mirrors that menu
/// entry-for-entry, so a member who knows the site finds everything where they
/// expect it. Opening the website's page here would be absurd — it exists to
/// tell a *browser* visitor that there is nothing to download yet — so the entry
/// is native and answers the question a member actually has once they are
/// already holding the app: **what is the app for, and what does it not do yet?**
///
/// ## Every live session option on the website links here
///
/// A member prices Custom video, Custom audio, Erotic video and Sex chat per
/// minute in credits, on her profile, and those prices are real and published.
/// **Nothing delivers a session.** There is no session backend, no call path, no
/// per-minute billing, on the website or in this app. The website sends every
/// one of those options to `/app`, which says so plainly rather than opening a
/// checkout that cannot complete, and this screen keeps that promise on the same
/// terms.
///
/// The temptation this screen exists to refuse is a "Start session" button that
/// goes somewhere. There is nowhere for it to go, and a control that silently
/// fails is worse than no control — the same rule that keeps the media
/// visibility toggle out of the app.
///
/// Deliberately no dates and no store badges: a ship date nobody can keep is the
/// one promise here that would cost something.
class GetTheAppScreen extends StatelessWidget {
  const GetTheAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('The Pinorpinor app')),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.handyman_rounded,
                            size: 12,
                            color: AppColors.goldLight,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'IN DEVELOPMENT',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'You are already using it',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This is the Pinorpinor app, and it is still being built. '
                      'Browsing, profiles, photos, saved profiles, contact '
                      'requests and messages all work now and talk to the same '
                      'account as the website.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD6D3D1),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Live sessions do not. Members can publish what they '
                      'charge per minute, and you can see those prices, but no '
                      'session can be started or paid for yet — not here and '
                      'not on the website.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD6D3D1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              Text(
                'What live sessions will be',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Rendered from the catalogue, not from a second hand-written
              // list: these are the same four options a member prices in Edit
              // Profile, and two copies of the wording is how the two drift.
              for (final LiveSessionOption option in kLiveSessions) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconFor(option.id),
                          size: 16,
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              option.label,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              option.description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Text(
                'Prices are set by each member and shown on her profile. '
                'Credits are the platform’s own unit and are bought over '
                'WhatsApp. Nothing is charged until sessions actually work and '
                'you start one yourself.',
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: AppSpacing.xl),
              GradientButton(
                label: 'Browse members',
                onPressed: () => context.go(AppRoutes.discover),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// Icons for the four catalogue ids. Unknown ids fall back rather than
  /// throwing: the catalogue is generated from the website and may gain an entry
  /// before this map does, and a missing icon must not take the screen down.
  static IconData _iconFor(String id) => switch (id) {
    'custom_video' => Icons.videocam_rounded,
    'custom_audio' => Icons.mic_rounded,
    'erotic_video' => Icons.local_fire_department_rounded,
    'sex_chat' => Icons.chat_bubble_rounded,
    _ => Icons.play_circle_outline_rounded,
  };
}
