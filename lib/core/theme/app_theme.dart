// CupertinoPageTransitionsBuilder lives in the cupertino library, not material.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Spacing scale, borrowed from the Tailwind rhythm the website uses.
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// The smallest square that still meets the 44px touch-target guideline the
  /// website's navigation already honours (`min-h-11`).
  static const double minTouchTarget = 44;
}

class AppRadius {
  const AppRadius._();

  /// The "tail" corner on a chat bubble — small enough to read as a point.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

/// The single theme definition.
///
/// The website ships one light identity — warm ivory, rose and gold — with no
/// theme switcher, so the app reproduces that rather than inventing a dark mode
/// the brand has never had. The structure is split so a dark variant can be
/// added later by supplying a second [ColorScheme] without touching any screen.
class AppTheme {
  const AppTheme._();

  static const String sansFamily = 'PlusJakartaSans';
  static const String displayFamily = 'PlayfairDisplay';

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.rose,
    onPrimary: Colors.white,
    primaryContainer: AppColors.badgeRoseBg,
    onPrimaryContainer: AppColors.badgeRoseFg,
    secondary: AppColors.gold,
    onSecondary: AppColors.textMain,
    secondaryContainer: AppColors.badgeGoldBg,
    onSecondaryContainer: AppColors.badgeGoldFg,
    tertiary: AppColors.burgundy,
    onTertiary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF991B1B),
    surface: AppColors.bgSecondary,
    onSurface: AppColors.textMain,
    surfaceContainerLowest: AppColors.bgSecondary,
    surfaceContainerLow: AppColors.bgPrimary,
    surfaceContainer: AppColors.bgMuted,
    surfaceContainerHigh: AppColors.bgCardHover,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    outlineVariant: AppColors.borderStrong,
    inverseSurface: AppColors.bgDark,
    onInverseSurface: AppColors.textInverse,
  );

  static ThemeData get light {
    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightScheme,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      fontFamily: sansFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          // Keeps the iOS swipe-back gesture on iOS and a native-feeling
          // forward push on Android.
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textMain,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: const Color(0x14000000),
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.bgSecondary,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderStrong,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(0, AppSpacing.minTouchTarget + 4),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: sansFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textMain,
          minimumSize: const Size(0, AppSpacing.minTouchTarget + 4),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: sansFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.rose,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          textStyle: const TextStyle(
            fontFamily: sansFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSecondary,
        // 16px matches the website's mobile input-zoom guard in globals.css:
        // iOS Safari force-zooms below it, and the app keeps the same floor so
        // form density reads identically on both.
        hintStyle: const TextStyle(
          fontFamily: sansFamily,
          fontSize: 16,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: sansFamily,
          fontSize: 14,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.rose, width: 1.6),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.6),
        errorStyle: const TextStyle(
          fontFamily: sansFamily,
          fontSize: 12.5,
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgMuted,
        selectedColor: AppColors.badgeRoseBg,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontFamily: sansFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgSecondary,
        selectedItemColor: AppColors.rose,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgSecondary,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.badgeRoseBg,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: sansFamily,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.rose : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.rose : AppColors.textMuted,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgSecondary,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgSecondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: const TextStyle(
          fontFamily: sansFamily,
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.rose
              : AppColors.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.rose,
        linearTrackColor: AppColors.bgMuted,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        minVerticalPadding: 12,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.rose,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.rose,
        dividerColor: AppColors.border,
        labelStyle: const TextStyle(
          fontFamily: sansFamily,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: sansFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _buildTextTheme() => const TextTheme(
    // Playfair Display carries the website's editorial headings.
    displaySmall: TextStyle(
      fontFamily: displayFamily,
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: AppColors.textMain,
    ),
    headlineMedium: TextStyle(
      fontFamily: displayFamily,
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.textMain,
    ),
    headlineSmall: TextStyle(
      fontFamily: displayFamily,
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.textMain,
    ),
    titleLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: AppColors.textMain,
    ),
    titleMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textMain,
    ),
    titleSmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textMain,
    ),
    bodyLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      height: 1.5,
      color: AppColors.textMain,
    ),
    bodyMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      height: 1.5,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12.5,
      height: 1.45,
      color: AppColors.textMuted,
    ),
    labelLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.textMain,
    ),
    labelMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: AppColors.textMuted,
    ),
  );
}
