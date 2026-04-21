import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/utils/app_snackbar.dart';

/// Download screen
///
/// Mirrors Blogger download page behavior:
/// - Shows YouTube watch URL
/// - Share via Snaptube (Android)
/// - Open via 9xbuddy (PC / iPhone)
class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      AdService.instance.showInterstitialForScreen('download_screen');
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 3.1 — Safe cast with null check (was hard cast — crashed if arguments null/wrong type)
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null || args['episode'] == null || args['watchUrl'] == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Download Episode'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text(
                'Episode data not found',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final episode = args['episode'] as EpisodeModel;
    final watchUrl = args['watchUrl'] as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Download Episode'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),

                _HeroIconSection(),

                const SizedBox(height: AppSpacing.xl),

                _DownloadCard(episode: episode, watchUrl: watchUrl),

                const SizedBox(height: AppSpacing.xl),

                OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    side: const BorderSide(
                      color: AppColors.primaryRed,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  child: Text(
                    'Back to Watch',
                    style: AppTypography.button.copyWith(
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero icon section with title
class _HeroIconSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.download_rounded,
            size: 48,
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Download Episode',
          style: AppTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Choose your download method below',
          style: AppTypography.body.copyWith(color: AppColors.softGrey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Download card with URL display and action buttons
class _DownloadCard extends StatelessWidget {
  final EpisodeModel episode;
  final String watchUrl;

  const _DownloadCard({required this.episode, required this.watchUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            episode.title,
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Episode ${episode.episodeNumber}',
            style: AppTypography.body.copyWith(color: AppColors.goldAccent),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'Download Link',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),

          // URL container — tap to copy
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: watchUrl));
              AppSnackbar.copied();
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: AppColors.goldAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      watchUrl,
                      style: AppTypography.body.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.goldAccent,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.softGrey,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Button 1: Snaptube
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _shareViaSnaptube(watchUrl, episode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share_rounded, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '📲 Download via Snaptube',
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Instructions note
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.darkBackground,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📱 Android:',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Download → choose Snaptube → select quality.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.softGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareViaSnaptube(String url, EpisodeModel episode) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'download_tapped',
      parameters: {'method': 'snaptube', 'episode_title': episode.title},
    );
    await Share.share(url, subject: '${episode.title} - Download');
  }
}
