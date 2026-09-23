import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Color Palette — Executive Modern Light Theme
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color lightSurfaceMuted = Color(0xFFF1F5F9); // Slate 100

  // Brand Accents
  static const Color navy900 = Color(0xFF0F172A); // Slate 900
  static const Color navy800 = Color(0xFF1E293B); // Slate 800
  static const Color navy700 = Color(0xFF334155); // Slate 700
  static const Color blue600 = Color(0xFF2563EB); // Royal Blue
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue50 = Color(0xFFEFF6FF); // Soft Blue Tint
  static const Color blue100 = Color(0xFFDBEAFE);

  // Status Colors (WCAG compliant)
  static const Color present = Color(0xFF059669); // Emerald 600
  static const Color presentBg = Color(0xFFD1FAE5); // Emerald 100
  static const Color late = Color(0xFFD97706); // Amber 600
  static const Color lateBg = Color(0xFFFEF3C7); // Amber 100
  static const Color absent = Color(0xFFDC2626); // Red 600
  static const Color absentBg = Color(0xFFFEE2E2); // Red 100
  static const Color unmarked = Color(0xFF94A3B8); // Slate 400

  // Neutral Typography
  static const Color textDark = Color(0xFF0F172A); // Slate 900
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textSubtle = Color(0xFF94A3B8); // Slate 400

  // Legacy Dark Theme Colors (retained for compatibility)
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF131A2B);
  static const Color surfaceLight = Color(0xFF1E283F);
  static const Color surfaceBorder = Color(0xFF2B3857);
  static const Color primary = Color(0xFF38BDF8);
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color secondary = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  // Modern Multi-Layer Elevation Shadows (prevents murky dark halos)
  static List<BoxShadow> get shadowSm => const [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => const [
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x0D0F172A),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get shadowLg => const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x120F172A),
          blurRadius: 28,
          offset: Offset(0, 10),
        ),
      ];

  /// Clean professional card decoration
  static BoxDecoration cardDecoration({
    Color color = Colors.white,
    double radius = 18,
    Border? border,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: lightSurfaceBorder, width: 1),
      boxShadow: shadows ?? shadowSm,
    );
  }

  /// Modern Executive Light Theme (Default)
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: navy900,
      colorScheme: const ColorScheme.light(
        primary: navy900,
        secondary: blue600,
        surface: lightSurface,
        error: absent,
        onPrimary: Colors.white,
        onSurface: textDark,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textDark,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: textMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        iconTheme: const IconThemeData(color: textDark),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightSurfaceBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy900,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy900,
          side: const BorderSide(color: lightSurfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: absent,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
    );
  }
}
