import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';

const String _vidblazeDownloadUrl = 'https://vidblaze.app/';

/// Type alias for backward compatibility
typedef VidBlazeInstallSheet = VidswiftInstallSheet;

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
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
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
                  color: AppColors.softGrey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Logo + Title + Trust Badge row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.darkBackground,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: AppColors.primaryRed.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Image.asset(
                        'assets/images/vidblazelogo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.download_for_offline_rounded,
                              color: AppColors.primaryRed,
                              size: 32,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VidBlaze Required', style: AppTypography.title),
                        const SizedBox(height: 2),
                        Text(
                          'Official Video Downloader by DramaHub',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.softGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 100% Safe Trust Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF34D399),
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '100% Safe • Built by DramaHub',
                                style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF34D399),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Capabilities / Trust Showcase Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.darkBackground.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: AppColors.softGrey.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.primaryRed,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Why install VidBlaze?',
                          style: AppTypography.title.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FeatureItem(
                      icon: Icons.movie_filter_rounded,
                      text: 'DramaHub Episodes: 1-Tap fast direct download',
                    ),
                    const SizedBox(height: 6),
                    _FeatureItem(
                      icon: Icons.public_rounded,
                      text:
                          'Multi-Platform: Download videos from YouTube, Instagram & 1,800+ sites',
                    ),
                    const SizedBox(height: 6),
                    _FeatureItem(
                      icon: Icons.hd_rounded,
                      text: 'High-speed downloads in full HD/8K quality',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Step-by-step instructions
              _InstructionRow(
                step: '1',
                text: 'Download and install VidBlaze on your device',
              ),
              const SizedBox(height: AppSpacing.sm),
              _InstructionRow(
                step: '2',
                text: 'Come back here and tap Download again',
              ),
              const SizedBox(height: AppSpacing.sm),
              _InstructionRow(
                step: '3',
                text: 'VidBlaze opens instantly — pick quality and enjoy',
              ),

              const SizedBox(height: AppSpacing.lg),

              // Get VidBlaze button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openVidblazeDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Get VidBlaze App — It\'s Free'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
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
                    style: AppTypography.body.copyWith(
                      color: AppColors.softGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVidblazeDownload() async {
    final uri = Uri.parse(_vidblazeDownloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: AppColors.primaryRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
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
            color: AppColors.primaryRed.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryRed,
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
