import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/brand.dart';

/// The 18+ and adult-content notice, shown before the app is usable.
///
/// ## What this is, and what it is not
///
/// It is a disclosure: it tells someone what they are about to see and asks
/// them to confirm they are old enough. It is **not** an access control and is
/// not presented as one. A determined minor taps "I am 18 or over", exactly as
/// they do on every site that shows this screen.
///
/// The controls that actually do work are elsewhere and are server-side: date
/// of birth is validated at registration, `requireAuth()` re-reads the account
/// on every request, media is held for human moderation, and "this person
/// appears to be under 18" is one of the report reasons. This screen exists
/// because both app stores expect an adult-oriented app to state its nature up
/// front, and because someone who did not intend to open an adult platform
/// deserves to be told before the first profile photo loads.
///
/// The decline path leaves rather than nagging. An app that will not let you
/// say no is worse than one that does.
class AgeGateScreen extends StatelessWidget {
  const AgeGateScreen({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final isCompact = Responsive.of(context).isCompact;

    return PopScope(
      // Back must not dismiss the gate — that would be a way past it that costs
      // less than reading it.
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.bgDark,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? AppSpacing.xl : AppSpacing.xxl,
                    vertical: AppSpacing.xxl,
                  ),
                  child: ContentContainer(
                    maxWidth: 460,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Center(
                          child: BrandMark(size: 26, onLight: false),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.rose.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: AppColors.rose.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.shield_outlined,
                                size: 13,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'ADULTS ONLY · 18+',
                                style: TextStyle(
                                  fontFamily: AppTheme.sansFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        Text(
                          'This is an adult platform',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.displayFamily,
                            fontSize: isCompact ? 26 : 30,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Text(
                          'Pinorpinor is a social discovery and meetup platform for '
                          'adults. Profiles contain photographs and videos posted by '
                          'members, and conversations here are between adults.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.sansFamily,
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        const _Assurance(
                          icon: Icons.verified_user_outlined,
                          text:
                              'Every photo and video is reviewed by a moderator '
                              'before anyone else can see it.',
                        ),
                        const _Assurance(
                          icon: Icons.lock_outline_rounded,
                          text:
                              'Phone numbers are never published. Contact happens '
                              'only when a member accepts your request.',
                        ),
                        const _Assurance(
                          icon: Icons.flag_outlined,
                          text:
                              'You can block or report anyone, from any profile or '
                              'conversation.',
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        GradientButton(
                          label: 'I am 18 or over — continue',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            onAccept();
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        TextButton(
                          onPressed: onDecline,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.72,
                            ),
                          ),
                          child: const Text('I am under 18 — leave'),
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        const Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            _LegalLink(label: 'Terms', url: AppConfig.termsUrl),
                            _Dot(),
                            _LegalLink(
                              label: 'Privacy',
                              url: AppConfig.privacyPolicyUrl,
                            ),
                            _Dot(),
                            _LegalLink(
                              label: 'Safety',
                              url: AppConfig.safetyUrl,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Assurance extends StatelessWidget {
  const _Assurance({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.sansFamily,
                fontSize: 12.5,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => LegalLinks.open(context, url),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        foregroundColor: Colors.white.withValues(alpha: 0.6),
        textStyle: const TextStyle(
          fontFamily: AppTheme.sansFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) =>
      Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.35)));
}

/// Shown after someone says they are under 18.
///
/// A dead end on purpose. Offering a "go back" button would make the decline a
/// speed bump rather than an answer, and the whole point is that the honest
/// answer is respected.
class AgeGateDeclinedScreen extends StatelessWidget {
  const AgeGateDeclinedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: ContentContainer(
                  maxWidth: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.do_not_disturb_on_outlined,
                        size: 42,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'You need to be 18 or over',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.displayFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Thanks for being honest. Pinorpinor is only for adults, '
                        'so you can close this app now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.sansFamily,
                          fontSize: 14,
                          height: 1.6,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
