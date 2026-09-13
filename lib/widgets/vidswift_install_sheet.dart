import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';

// TODO: Replace with Play Store link or direct APK URL once distribution is set up
const String _vidswiftDownloadUrl = 'https://vidswift.app/download';

class VidswiftInstallSheet extends StatelessWidget {
  const VidswiftInstallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.softGrey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Icon + title row
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(
                  Icons.download_for_offline_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VidSwift Required', style: AppTypography.title),
                    const SizedBox(height: 2),
                    Text(
                      'Free YouTube downloader by DramaHub',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.softGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Instructions
          _InstructionRow(
            step: '1',
            text: 'Download and install VidSwift on your device',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InstructionRow(
            step: '2',
            text: 'Come back here and tap Download again',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InstructionRow(
            step: '3',
            text: 'VidSwift opens instantly — pick quality and download',
          ),

          const SizedBox(height: AppSpacing.lg),

          // Get VidSwift button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openVidswiftDownload,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Get VidSwift — It\'s Free'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Not now
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Not Now',
                style: AppTypography.body.copyWith(color: AppColors.softGrey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openVidswiftDownload() async {
    final uri = Uri.parse(_vidswiftDownloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.step, required this.text});

  final String step;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: AppTypography.body),
          ),
        ),
      ],
    );
  }
}
