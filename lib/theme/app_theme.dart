import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Forest Green Palette
  static const Color forestGreen = Color(0xFF135238);
  static const Color forestGreenDark = Color(0xFF0D3B28);
  static const Color forestGreenLight = Color(0xFF1B6B4A);
  static const Color forestGreenMuted = Color(0xFF94B5A5);

  // Background & Surfaces
  static const Color scaffoldBg = Color(0xFFF7FAF8);
  static const Color surfaceWhite = Colors.white;
  static const Color tableHeaderBg = Color(0xFFEDF5F0);
  static const Color tableBorder = Color(0xFFE5ECE7);

  // Accent & Status
  static const Color mintBadgeBg = Color(0xFFE1F8EC);
  static const Color mintCheck = Color(0xFF12824C);
  static const Color liveGreenDot = Color(0xFF10B981);
  static const Color warningRed = Color(0xFFDC2626);
  static const Color warningBg = Color(0xFFFEE2E2);

  // Text
  static const Color textDark = Color(0xFF141F1A);
  static const Color textMuted = Color(0xFF6B7A72);
  static const Color textSubtle = Color(0xFF9BA6A0);
  static const Color placeholderText = Color(0xFFA0ABA5);
  static const Color headerColumnText = Color(0xFF336049);
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forestGreen,
        primary: AppColors.forestGreen,
        surface: AppColors.surfaceWhite,
      ),
      textTheme: textTheme.copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: -0.2,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.tableBorder, width: 1),
        ),
      ),
    );
  }
}
