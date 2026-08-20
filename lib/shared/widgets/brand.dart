import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The Pinorpinor wordmark, matching the website's header.
///
/// "pinor" in charcoal, "pinor" in rose, Playfair Display, with the flame tile
/// on a rose-to-burgundy gradient and the "Verified Members Only" strapline.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.showStrapline = true,
    this.size = 20,
    this.onLight = true,
  });

  final bool showStrapline;
  final double size;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final tile = size * 1.8;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            gradient: AppColors.roseGradient,
            borderRadius: BorderRadius.circular(tile * 0.32),
            boxShadow: AppColors.roseShadow,
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            size: tile * 0.56,
            color: Colors.white,
          ),
        ),
        SizedBox(width: size * 0.5),
        // Flexible so the wordmark and strapline can shrink rather than push
        // the row past its constraints on a 320px phone or at a large text
        // scale. Without it the header overflows exactly as the website's did
        // before its own fix.
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Semantics carries the whole name so a screen reader announces
              // "pinorpinor" once rather than reading two coloured fragments.
              Semantics(
                header: true,
                label: 'Pinorpinor',
                child: ExcludeSemantics(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: AppTheme.displayFamily,
                        fontSize: size,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        letterSpacing: -0.4,
                        color: onLight ? AppColors.textMain : Colors.white,
                      ),
                      children: const <TextSpan>[
                        TextSpan(text: 'pinor'),
                        TextSpan(
                          text: 'pinor',
                          style: TextStyle(color: AppColors.rose),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showStrapline) ...<Widget>[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 9,
                      color: AppColors.rose,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'VERIFIED MEMBERS ONLY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.sansFamily,
                          fontSize: size * 0.42,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: onLight
                              ? AppColors.textSecondary
                              : Colors.white.withValues(alpha: 0.7),
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
    );
  }
}

/// The website's `.gradient-btn` — a rose-gradient pill with a lifted shadow.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.gradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? (gradient ?? AppColors.roseGradient)
            : const LinearGradient(
                colors: <Color>[AppColors.borderStrong, AppColors.borderStrong],
              ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: enabled ? AppColors.roseShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: enabled ? onPressed : null,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget + 4,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.sansFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The website's `.badge-*` family: a small pill with a tinted background and a
/// matching border.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
    this.icon,
    this.dense = false,
  });

  const AppBadge.verified({super.key, this.dense = false})
    : label = 'Verified',
      background = AppColors.badgeVerifiedBg,
      foreground = AppColors.badgeVerifiedFg,
      border = AppColors.badgeVerifiedBorder,
      icon = Icons.verified_rounded;

  const AppBadge.availableToday({super.key, this.dense = false})
    : label = 'Available today',
      background = AppColors.badgeRoseBg,
      foreground = AppColors.badgeRoseFg,
      border = AppColors.badgeRoseBorder,
      icon = Icons.bolt_rounded;

  const AppBadge.boosted({super.key, this.dense = false})
    : label = 'Red hot',
      background = AppColors.badgeGoldBg,
      foreground = AppColors.badgeGoldFg,
      border = AppColors.badgeGoldBorder,
      icon = Icons.local_fire_department_rounded;

  const AppBadge.newProfile({super.key, this.dense = false})
    : label = 'New',
      background = AppColors.badgeGoldBg,
      foreground = AppColors.badgeGoldFg,
      border = AppColors.badgeGoldBorder,
      icon = Icons.auto_awesome_rounded;

  /// "Online now" only. The other presence buckets deliberately have no badge:
  /// a dot for "active this week" makes an absent member look present, which is
  /// the misreading the coarse buckets exist to prevent.
  const AppBadge.onlineNow({super.key, this.dense = false})
    : label = 'Online now',
      background = AppColors.badgeVerifiedBg,
      foreground = AppColors.badgeVerifiedFg,
      border = AppColors.badgeVerifiedBorder,
      icon = Icons.circle;

  const AppBadge.location({super.key, required this.label, this.dense = false})
    : background = AppColors.badgeLocationBg,
      foreground = AppColors.badgeLocationFg,
      border = AppColors.badgeLocationBorder,
      icon = Icons.place_rounded;

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 9 : 11, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.sansFamily,
              fontSize: dense ? 9.5 : 11,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
