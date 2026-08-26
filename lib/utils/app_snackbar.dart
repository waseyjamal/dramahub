import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSnackbar {
  AppSnackbar._();

  static void _show({
    required String title,
    required String message,
    required Color backgroundColor,
    required Icon icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      icon: icon,
      titleText: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      borderRadius: 14,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      animationDuration: const Duration(milliseconds: 400),
      boxShadows: [const BoxShadow(color: Colors.black45, blurRadius: 8)],
    );
  }

  static void success(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: const Color(0xFF1A1A2E),
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFFF39C12),
          size: 28,
        ),
      );

  static void error(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: const Color(0xFFC0392B),
        icon: const Icon(Icons.error_rounded, color: Colors.white, size: 28),
      );

  static void info(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: const Color(0xFF16213E),
        icon: const Icon(
          Icons.info_rounded,
          color: Color(0xFFF39C12),
          size: 28,
        ),
      );

  static void warning(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: const Color(0xFF2C2C54),
        icon: const Icon(
          Icons.warning_rounded,
          color: Color(0xFFF39C12),
          size: 28,
        ),
      );

  static void copied() => _show(
        title: 'Copied!',
        message: 'Link copied to clipboard',
        backgroundColor: const Color(0xFF1A1A2E),
        icon: const Icon(
          Icons.copy_rounded,
          color: Color(0xFFF39C12),
          size: 28,
        ),
        duration: const Duration(seconds: 2),
      );
}
