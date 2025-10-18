import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    fontFamily: AppTextStyles.fontFamily,
  textTheme: GoogleFonts.openSansTextTheme(const TextTheme(
      headlineLarge: AppTextStyles.heading1,
      headlineMedium: AppTextStyles.heading2,
      bodyMedium: AppTextStyles.body,
      labelLarge: AppTextStyles.button,
    )),
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.background,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.primary,
    fontFamily: AppTextStyles.fontFamily,
  textTheme: GoogleFonts.openSansTextTheme(const TextTheme(
      headlineLarge: AppTextStyles.heading1,
      headlineMedium: AppTextStyles.heading2,
      bodyMedium: AppTextStyles.body,
      labelLarge: AppTextStyles.button,
    )),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.darkBackground,
    ),
  );
}