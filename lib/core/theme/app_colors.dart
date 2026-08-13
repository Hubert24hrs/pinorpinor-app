import 'package:flutter/material.dart';

/// The Pinorpinor palette, transcribed from `src/app/globals.css` on the website.
///
/// Names match the CSS custom properties so the two stay comparable: if the site
/// changes `--accent-rose`, exactly one constant changes here.
class AppColors {
  const AppColors._();

  // Backgrounds — warm ivory and pristine neutral.
  static const bgPrimary = Color(0xFFFAF8F5);
  static const bgSecondary = Color(0xFFFFFFFF);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgCardHover = Color(0xFFF8F6F2);
  static const bgMuted = Color(0xFFF2EFE9);
  static const bgDark = Color(0xFF141216);

  // Brand accents — refined rose, deep burgundy, luxury gold.
  static const rose = Color(0xFFC2446E);
  static const roseHover = Color(0xFFA03357);
  static const burgundy = Color(0xFF7C1D38);
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFF4E7B3);
  static const goldDeep = Color(0xFFAA820A);
  static const charcoal = Color(0xFF1E1B22);

  // Status.
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Text.
  static const textMain = Color(0xFF1C1917);
  static const textSecondary = Color(0xFF57534E);
  static const textMuted = Color(0xFFA8A29E);
  static const textInverse = Color(0xFFFAF8F5);

  // Borders.
  static const border = Color(0xFFE7E3DC);
  static const borderStrong = Color(0xFFD6D0C5);
  static const borderActive = Color(0x66C2446E);

  // Badge surfaces, matching `.badge-*` on the website.
  static const badgeVerifiedBg = Color(0xFFECFDF5);
  static const badgeVerifiedFg = Color(0xFF047857);
  static const badgeVerifiedBorder = Color(0xFFA7F3D0);

  static const badgeRoseBg = Color(0xFFFDF2F5);
  static const badgeRoseFg = Color(0xFF9B2646);
  static const badgeRoseBorder = Color(0xFFFBCFE8);

  static const badgeGoldBg = Color(0xFFFEFCE8);
  static const badgeGoldFg = Color(0xFF854D0E);
  static const badgeGoldBorder = Color(0xFFFEF08A);

  static const badgeLocationBg = Color(0xFFF5F2EC);
  static const badgeLocationFg = Color(0xFF44403C);
  static const badgeLocationBorder = Color(0xFFE7E3DC);

  // Skeleton shimmer stops.
  static const skeletonBase = Color(0xFFF5F2EC);
  static const skeletonHighlight = Color(0xFFE7E3DC);

  /// `--accent-gradient`
  static const roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[rose, burgundy],
  );

  /// `--accent-gradient-gold`
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[gold, goldDeep],
  );

  /// `--hero-gradient`
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF18151D), Color(0xFF2A1E29), Color(0xFF141216)],
    stops: <double>[0, 0.5, 1],
  );

  /// `--shadow-card`
  static const cardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D1C1917),
      blurRadius: 30,
      spreadRadius: -5,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x051C1917),
      blurRadius: 6,
      spreadRadius: -4,
      offset: Offset(0, 4),
    ),
  ];

  /// `--shadow-rose`
  static const roseShadow = <BoxShadow>[
    BoxShadow(color: Color(0x40C2446E), blurRadius: 20, offset: Offset(0, 6)),
  ];
}
