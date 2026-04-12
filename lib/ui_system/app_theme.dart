import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'radius.dart';

/// Drama Hub Application Theme
class AppTheme {
  /// Dark Theme for Drama Hub
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryRed,
      secondary: AppColors.goldAccent,
      surface: AppColors.cardBackground,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.darkBackground,

    // Card
    cardColor: AppColors.cardBackground,
    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.title,
      iconTheme: const IconThemeData(color: AppColors.white),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        shadowColor: AppColors.primaryRed.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: AppTypography.button,
      ),
    ),

    // Text Theme
    textTheme: AppTypography.textTheme,

    // Icon Theme
    iconTheme: const IconThemeData(color: AppColors.white),
  );
}
