import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SiKasirSahaja Design System — Modern Mobile Material 3 Theme.
///
/// Built from the brand design tokens:
/// - Primary: Deep Ocean Blue (#002D54) — trust & reliability
/// - Secondary: Merchant Green (#006D3D) — success & growth
/// - Tertiary: Neutral Dark (#292D2F) — structure
/// - Typography: Hanken Grotesk (UI), JetBrains Mono (numeric)
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ───────────────────────────────────────────
  static const Color primary = Color(0xFF002D54);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1B446F);
  static const Color onPrimaryContainer = Color(0xFFD6E6FF);
  static const Color inversePrimary = Color(0xFFA4C9FC);

  static const Color secondary = Color(0xFF006D3D);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD1FAE5);
  static const Color onSecondaryContainer = Color(0xFF065F46);

  static const Color tertiary = Color(0xFF292D2F);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF3F4346);
  static const Color onTertiaryContainer = Color(0xFFACB0B2);

  static const Color error = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);

  static const Color surface = Color(0xFFF5F8FA);
  static const Color surfaceDim = Color(0xFFDCE3E8);
  static const Color surfaceBright = Color(0xFFF8FAFC);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFE8EFF5);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color surfaceContainerHighest = Color(0xFFCBD5E1);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF475569);
  static const Color inverseSurface = Color(0xFF1E293B);
  static const Color inverseOnSurface = Color(0xFFF1F5F9);

  static const Color outline = Color(0xFF64748B);
  static const Color outlineVariant = Color(0xFFE2E8F0);
  static const Color surfaceTint = Color(0xFF3B608D);

  // ─── Gradients & Shadows ────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF002546), Color(0xFF0A487C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF006D3D), Color(0xFF059656)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.02),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.14),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // ─── Spacing ────────────────────────────────────────────────
  static const double spacingBase = 8.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  static const double containerPadding = 16.0;
  static const double gutterGrid = 12.0;
  static const double touchTarget = 48.0;
  static const double sidebarWidth = 280.0;

  // ─── Modern Mobile Border Radius ────────────────────────────
  static const double radiusSm = 6.0;
  static const double radiusDefault = 10.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 28.0;
  static const double radiusFull = 9999.0;

  // ─── Light Theme ────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      inversePrimary: inversePrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      inverseSurface: inverseSurface,
      onInverseSurface: inverseOnSurface,
      outline: outline,
      outlineVariant: outlineVariant,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: _textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onPrimary,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(64, touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outlineVariant, width: 1.5),
          minimumSize: const Size(64, touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 1.8),
        ),
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          color: onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          color: outline,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLow,
        selectedColor: primary,
        secondarySelectedColor: primary,
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        secondaryLabelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        side: const BorderSide(color: outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverseSurface,
        contentTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: inverseOnSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceContainerLowest,
        selectedItemColor: primary,
        unselectedItemColor: outline,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceContainerLowest,
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme: const IconThemeData(color: onSurfaceVariant),
        selectedLabelTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        unselectedLabelTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: onSecondary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXl),
          ),
        ),
      ),
    );
  }

  // ─── Text Theme ─────────────────────────────────────────────
  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.hankenGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 48 / 40,
        color: onSurface,
      ),
      displayMedium: GoogleFonts.hankenGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        color: onSurface,
      ),
      displaySmall: GoogleFonts.hankenGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 36 / 28,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.hankenGrotesk(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 38 / 30,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.hankenGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        color: onSurface,
      ),
      headlineSmall: GoogleFonts.hankenGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 28 / 20,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.hankenGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 28 / 20,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: onSurface,
      ),
      titleSmall: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: onSurface,
      ),
      bodySmall: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: onSurface,
      ),
      labelMedium: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.3,
        color: onSurface,
      ),
      labelSmall: GoogleFonts.hankenGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
        letterSpacing: 0.3,
        color: onSurfaceVariant,
      ),
    );
  }

  /// Numeric text style for prices, totals, quantities.
  /// Uses JetBrains Mono for tabular alignment.
  static TextStyle get numericStyle => GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 20 / 16,
        color: onSurface,
      );

  /// Large numeric style for main totals (e.g. "Rp 2.450.000").
  static TextStyle get numericLargeStyle => GoogleFonts.jetBrainsMono(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 34 / 26,
        color: onSurface,
      );

  /// Small numeric style for item prices.
  static TextStyle get numericSmallStyle => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 18 / 13,
        color: onSurface,
      );
}
