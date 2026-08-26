import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/utils/constants.dart';

/// ✅ 8.8 — Shared TelegramCTA widget extracted from home_screen and video_screen
/// Single source of truth for the Telegram button
class TelegramCTAButton extends StatelessWidget {
  const TelegramCTAButton({super.key});

  Future<void> _openTelegram() async {
    try {
      final config = AppConfigService.instance.config;
      if (!AppUrls.isSafeUrl(config.telegramUrl)) return;
      final url = Uri.parse(config.telegramUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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
