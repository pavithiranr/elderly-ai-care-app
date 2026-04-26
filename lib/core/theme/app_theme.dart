import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color accentRed = Color(0xFFDC2626);
  static const Color backgroundGray = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMid = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color divider = Color(0xFFE2E8F0);

  // ── High Contrast Mode Colors ──────────────────────────────────────
  static const Color highContrastPrimaryBlue = Color(0xFF0000FF); // Pure blue
  static const Color highContrastTextDark = Color(0xFF000000);   // Pure black
  static const Color highContrastBg = Color(0xFFFFFFFF);         // Pure white
  static const Color highContrastAccentGreen = Color(0xFF008000); // Pure green
  static const Color highContrastAccentRed = Color(0xFFFF0000);   // Pure red

  // ── Color Blind Mode Colors (Deuteranopia - Red-Green friendly) ────
  static const Color colorBlindPrimaryBlue = Color(0xFF0173B2);  // Blue-friendly
  static const Color colorBlindAccent1 = Color(0xFFE9A806);       // Orange (more visible)
  static const Color colorBlindAccent2 = Color(0xFF5A4A42);      // Brown
  static const Color colorBlindAccent3 = Color(0xFF05668D);      // Dark blue alternative

  // Elderly-specific sizes — large and accessible (minimum 22px body text)
  static const double elderlyBodyFontSize = 22.0;
  static const double elderlySubFontSize = 22.0;   // secondary/caption — still meets minimum
  static const double elderlyTitleFontSize = 32.0;
  static const double elderlyButtonHeight = 64.0;
  static const double elderlyIconSize = 38.0;

  /// Get light theme (normal colors)
  static ThemeData lightTheme({
    double textScale = 1.0,
    bool isHighContrast = false,
    bool isColorBlind = false,
  }) {
    final primaryColor = isHighContrast
        ? highContrastPrimaryBlue
        : (isColorBlind ? colorBlindPrimaryBlue : primaryBlue);

    // High contrast light mode: light gray background for contrast, pure black text
    const highContrastLightBg = Color(0xFFF0F0F0); // Light gray for contrast
    const highContrastLightSurface = Color(0xFFFFFFFF); // Pure white for cards
    
    // Color blind mode: use a slightly warmer/different background
    const colorBlindLightBg = Color(0xFFFAF8F3); // Warm light background
    const colorBlindLightSurface = Color(0xFFFFFFFF); // White for cards
    
    final bgColor = isHighContrast 
        ? highContrastLightBg 
        : (isColorBlind ? colorBlindLightBg : backgroundGray);
    final surfaceColor = isHighContrast 
        ? highContrastLightSurface 
        : (isColorBlind ? colorBlindLightSurface : surfaceWhite);
    final textColorDark = isHighContrast ? highContrastTextDark : textDark;
    final dividerColor = isHighContrast ? Colors.black : divider;

    final base = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: bgColor,
      ),
      scaffoldBackgroundColor: bgColor,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32 * textScale,
          fontWeight: FontWeight.bold,
          color: textColorDark,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24 * textScale,
          fontWeight: FontWeight.w600,
          color: textColorDark,
          height: 1.2,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: (22 * textScale).clamp(16.0, 44.0),
          color: textColorDark,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: (18 * textScale).clamp(14.0, 36.0),
          color: textColorDark,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: (20 * textScale).clamp(16.0, 32.0),
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 52 * textScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isHighContrast ? BorderSide(color: textColorDark, width: 3) : BorderSide.none,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: (18 * textScale).clamp(16.0, 32.0),
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: dividerColor,
            width: isHighContrast ? 2 : 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: textColorDark,
          size: 28 * textScale,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: (20 * textScale).clamp(18.0, 32.0),
          fontWeight: FontWeight.w600,
          color: textColorDark,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: surfaceColor,
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16 * textScale,
          vertical: 16 * textScale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dividerColor,
            width: isHighContrast ? 2 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dividerColor,
            width: isHighContrast ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryColor,
            width: isHighContrast ? 4 : 2,
          ),
        ),
      ),
    );
  }

  /// Get dark theme
  static ThemeData darkTheme({
    double textScale = 1.0,
    bool isHighContrast = false,
    bool isColorBlind = false,
  }) {
    // For dark mode high contrast, use bright colors on pure black
    final primaryColor = isHighContrast
        ? Color(0xFFFFFF00) // Bright yellow for maximum contrast on dark
        : (isColorBlind ? colorBlindPrimaryBlue : primaryBlue);

    // ── Material Design 3 Dark Mode Surface Elevation ──────────────────
    // These colors create visual depth without harsh glare
    const darkBgColor = Color(0xFF121212);           // Scaffold background (darkest)
    const darkSurfaceColor = Color(0xFF1E1E1E);     // Card/elevated surface (slightly lighter)
    const darkTextColor = Color(0xFFFFFFFF);        // Primary text (pure white for contrast)
    
    // High contrast uses pure colors for accessibility
    const highContrastDarkBg = Color(0xFF000000);       // Pure black
    const highContrastDarkSurface = Color(0xFF1A1A1A); // Near-pure black
    const highContrastDarkText = Color(0xFFFFFFFF);    // Pure white
    const highContrastDarkDivider = Color(0xFFFFFFFF); // Pure white dividers
    
    const darkDividerColor = Color(0xFF3F3F3F);     // Slightly lighter for non-elevated

    // Choose colors based on accessibility mode
    final bgColor = isHighContrast ? highContrastDarkBg : darkBgColor;
    final surfaceColor = isHighContrast ? highContrastDarkSurface : darkSurfaceColor;
    final textColorDark = isHighContrast ? highContrastDarkText : darkTextColor;
    final dividerColor = isHighContrast ? highContrastDarkDivider : darkDividerColor;

    final base = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: bgColor,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32 * textScale,
          fontWeight: FontWeight.bold,
          color: textColorDark,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24 * textScale,
          fontWeight: FontWeight.w600,
          color: textColorDark,
          height: 1.2,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: (22 * textScale).clamp(16.0, 44.0),
          color: textColorDark,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: (18 * textScale).clamp(14.0, 36.0),
          color: textColorDark,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: (20 * textScale).clamp(16.0, 32.0),
          fontWeight: FontWeight.w600,
          color: textColorDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textColorDark,
          minimumSize: Size(double.infinity, 52 * textScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isHighContrast ? BorderSide(color: textColorDark, width: 3) : BorderSide.none,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: (18 * textScale).clamp(16.0, 32.0),
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: dividerColor,
            width: isHighContrast ? 2 : 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: textColorDark,
          size: 28 * textScale,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: (20 * textScale).clamp(18.0, 32.0),
          fontWeight: FontWeight.w600,
          color: textColorDark,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: surfaceColor,
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16 * textScale,
          vertical: 16 * textScale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dividerColor,
            width: isHighContrast ? 2 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dividerColor,
            width: isHighContrast ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryColor,
            width: isHighContrast ? 4 : 2,
          ),
        ),
      ),
    );
  }
}
