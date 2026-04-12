import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/ui_system/spacing.dart';

/// ✅ 8.8 — Shared TelegramCTA widget extracted from home_screen and video_screen
/// Single source of truth for the Telegram button
class TelegramCTAButton extends StatelessWidget {
  const TelegramCTAButton({super.key});

  Future<void> _openTelegram() async {
    final config = AppConfigService.instance.config;
    final url = Uri.parse(config.telegramUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        _openTelegram();
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      ),
      child: const Text('📢 Join Telegram for Updates'),
    );
  }
}
