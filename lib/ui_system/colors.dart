import 'package:flutter/material.dart';

/// Drama Hub Brand Colors
class AppColors {
  // Primary Brand Colors
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color secondaryDark = Color(0xFF141414);
  static const Color cardBackground = Color(0xFF1C1C1C);
  static const Color softGrey = Color(0xFFA0A0A0);
  static const Color goldAccent = Color(0xFFF5C518);
  static const Color white = Color(0xFFFFFFFF);

  // Gradients
  static const Gradient redGlowGradient = RadialGradient(
    colors: [
      Color(0x26E50914), // Red at 15% opacity
      Colors.transparent,
    ],
    radius: 1.5,
    center: Alignment.topCenter,
  );
}
