import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/utils/constants.dart';

/// Full-screen "Update Required" page drawn above the Navigator.
/// It is not a route, so back presses, notifications and navigation
/// cannot remove it — only ForceUpdateService.isBlocked turning false can.
class ForceUpdateBlocker extends StatelessWidget {
  const ForceUpdateBlocker({super.key});

  Future<void> _open(String url) async {
    if (!AppUrls.isSafeUrl(url)) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = AppConfigService.instance.config.fallbackUpdate;
    // If admin disabled both options, still give users a way to update.
    final showWebsite = fallback.websiteEnabled || !fallback.telegramEnabled;

    return Material(
      color: AppColors.darkBackground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_rounded,
                      color: AppColors.primaryRed, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('Update Required',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  'This version of Drama Hub is no longer supported. '
                  'Please install the latest version to continue.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (showWebsite)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _open(fallback.websiteUrl),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (fallback.telegramEnabled) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _open(fallback.telegramUrl),
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white70, size: 18),
                      label: const Text('Get Update on Telegram',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
