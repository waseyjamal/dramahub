import 'package:flutter/material.dart';
import 'colors.dart';

/// Drama Hub Shadow Presets
class AppShadows {
  /// Soft shadow for cards
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  /// Red glow shadow for primary buttons
  static List<BoxShadow> redGlowShadow = [
    BoxShadow(
      color: AppColors.primaryRed.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
