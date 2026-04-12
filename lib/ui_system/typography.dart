import 'package:flutter/material.dart';
import 'colors.dart';

/// Drama Hub Typography System
class AppTypography {
  /// Headline Large - Poppins Bold
  static TextStyle headlineLarge = const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  /// Headline Medium - Poppins Bold
  static TextStyle headlineMedium = const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  /// Title - Poppins SemiBold
  static TextStyle title = const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Body - Inter Regular
  static TextStyle body = const TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.softGrey,
  );

  /// Caption - Inter Regular (smaller)
  static TextStyle caption = const TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.softGrey,
  );

  /// Button - Poppins SemiBold
  static TextStyle button = const TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Create TextTheme for Material Theme
  static TextTheme textTheme = TextTheme(
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    titleLarge: title,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
  );
}
