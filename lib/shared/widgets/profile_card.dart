import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/profile.dart';
import 'brand.dart';
import 'profile_image.dart';
import 'states.dart';

/// The shared profile card, matching `components/profile/ProfileCard.tsx`.
///
/// A tall photo with a charcoal gradient scrim, the name/age line and place over
/// it, and the status badges pinned to the top corner. The website's `.tilt-card`
/// hover is replaced with a press-scale, which is the mobile equivalent of the
/// same idea — and it is suppressed when the platform asks for reduced motion.
class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.aspectRatio = 3 / 4,
  });

  final ProfileSummary profile;
  final VoidCallback? onTap;
  final double aspectRatio;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = (_pressed && !reduceMotion) ? 0.975 : 1.0;

    final ageLabel = profile.age == null ? '' : ', ${profile.age}';

    return Semantics(
      button: widget.onTap != null,
      label:
          '${profile.displayName}$ageLabel'
          '${profile.placeLabel == null ? '' : ', ${profile.placeLabel}'}'
          '${profile.isVerified ? ', verified' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppColors.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ProfileImage(
                        url: profile.primaryPhoto?.url,
                        fallbackInitial: profile.displayName,
                        borderRadius: BorderRadius.zero,
                      ),
                      // Scrim: without it, white text over a pale photo becomes
                      // unreadable — a real failure on user-supplied images.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Color(0x1A141216),
                              Color(0xD9141216),
                            ],
                            stops: <double>[0.42, 0.64, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: <Widget>[
                            if (profile.isRedHot)
                              const AppBadge.boosted(dense: true),
                            if (profile.isFeatured && !profile.isRedHot)
                              const AppBadge.newProfile(dense: true),
                            if (profile.isAvailableToday)
                              const AppBadge.availableToday(dense: true),
                          ],
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        bottom: AppSpacing.md,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    '${profile.displayName}$ageLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.displayFamily,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (profile.isVerified) ...<Widget>[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 15,
                                    color: Color(0xFF6EE7B7),
                                  ),
                                ],
                              ],
                            ),
                            if (profile.placeLabel != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.place_rounded,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      profile.placeLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.sansFamily,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
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

/// The card's loading state, sized to match so the grid does not reflow when
/// real data arrives.
class ProfileCardSkeleton extends StatelessWidget {
  const ProfileCardSkeleton({super.key, this.aspectRatio = 3 / 4});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: const Skeleton(height: double.infinity, borderRadius: AppRadius.lg),
  );
}
