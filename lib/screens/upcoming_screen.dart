import 'package:flutter/material.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/upcoming_controller.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/utils/constants.dart';

/// Upcoming Episode screen
///
/// Displays countdown timer for unreleased episodes
/// Auto-redirects to video screen when countdown reaches zero
class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      AdService.instance.showInterstitialForScreen('upcoming_screen');
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UpcomingController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Coming Soon'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Banner Section
                _BannerSection(controller: controller),

                const SizedBox(height: AppSpacing.xl),

                // Timer Section
                _TimerSection(controller: controller),

                const SizedBox(height: AppSpacing.xl),

                // CTA Buttons
                _CTASection(controller: controller),

                const SizedBox(height: AppSpacing.xl),

                // Back Link
                _BackLink(),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner section with episode title and upcoming badge
class _BannerSection extends StatelessWidget {
  final UpcomingController controller;

  const _BannerSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondaryDark, AppColors.cardBackground],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Stack(
          children: [
            // Centered content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Upcoming badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'UPCOMING',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Episode title
                  Text(
                    controller.episode.title,
                    style: AppTypography.headlineMedium.copyWith(fontSize: 30),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    'Hindi Subtitles',
                    style: AppTypography.body.copyWith(
                      color: AppColors.softGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Timer section with countdown
class _TimerSection extends StatelessWidget {
  final UpcomingController controller;

  const _TimerSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 26,
      ),
      child: Column(
        children: [
          // Timer label
          Text(
            'EXPECTED RELEASE IN',
            style: AppTypography.caption.copyWith(
              color: AppColors.softGrey,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 14),

          // Timer boxes
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeBox(value: controller.days.value, label: 'DAYS'),
                const SizedBox(width: 10),
                _TimeBox(value: controller.hours.value, label: 'HOURS'),
                const SizedBox(width: 10),
                _TimeBox(value: controller.minutes.value, label: 'MINS'),
                const SizedBox(width: 10),
                _TimeBox(value: controller.seconds.value, label: 'SECS'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual time box
class _TimeBox extends StatelessWidget {
  final int value;
  final String label;

  const _TimeBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryRed,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// CTA section with premium and telegram buttons
class _CTASection extends StatelessWidget {
  final UpcomingController controller;

  const _CTASection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Premium CTA title
          Text(
            '💎 Want to Watch Now?',
            style: AppTypography.title.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // Premium button
          ElevatedButton(
            onPressed: () {
              Get.toNamed(AppRoutes.premium);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: const BorderSide(color: AppColors.softGrey, width: 1),
              ),
            ),
            child: Text(
              '⚡ Abhi Episode ${controller.episode.episodeNumber} dekhein (Instant Access)',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // Divider
          Container(
            height: 1,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.white.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Telegram CTA title
          Text(
            '⬇️ Join Telegram for Updates',
            style: AppTypography.title.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // Telegram button
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final url = Uri.parse(AppUrls.telegram);
              canLaunchUrl(url).then((can) {
                if (can) launchUrl(url, mode: LaunchMode.externalApplication);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            child: Text(
              'Join Telegram Channel',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back link
class _BackLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Get.back();
      },
      child: Text(
        '🔙 Back to Episode List',
        style: AppTypography.body.copyWith(
          color: AppColors.softGrey,
          fontSize: 13,
        ),
      ),
    );
  }
}
