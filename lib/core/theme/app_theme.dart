import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for the app — mirrors the marketing site's
/// Poppins/Inter typography and deep-green brand palette.
class AppTheme {
  AppTheme._();

  static const Color deepGreen = Color(0xFF0F6B3A);
  static const Color brandGreen = Color(0xFF3AB32A);
  static const Color charcoal = Color(0xFF1A1F1B);
  static const Color offWhite = Color(0xFFF7F8F5);
  static const Color mutedGrey = Color(0xFF6B7268);
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color lightGreenBg = Color(0xFFE7F5EA);
  static const Color warnRed = Color(0xFFB3261E);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: Brightness.light,
      primary: deepGreen,
      secondary: brandGreen,
      surface: Colors.white,
      error: warnRed,
    );

    final baseText = GoogleFonts.interTextTheme();
    final textTheme = baseText.copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        color: charcoal,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        color: charcoal,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: charcoal,
      ),
      titleLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: charcoal,
      ),
      titleMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: charcoal,
      ),
      titleSmall: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: charcoal,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(color: charcoal),
      bodyMedium: baseText.bodyMedium?.copyWith(color: charcoal),
      bodySmall: baseText.bodySmall?.copyWith(color: mutedGrey),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: offWhite,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: deepGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGrey),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightGreenBg,
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: deepGreen,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: deepGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deepGreen,
          side: const BorderSide(color: deepGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: deepGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandGreen, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: borderGrey, thickness: 1),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: deepGreen,
        selectedTileColor: lightGreenBg,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
