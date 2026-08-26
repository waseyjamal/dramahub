import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/upcoming_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/utils/constants.dart';

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
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.white,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Coming Soon',
          style: AppTypography.title.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // ── Banner ──
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.large),
                child: Stack(
                  children: [
                    // Banner image
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: controller.dramaBanner.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: controller.dramaBanner,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              placeholder: (c, u) =>
                                  Container(color: AppColors.secondaryDark),
                              errorWidget: (c, u, e) => Container(
                                color: AppColors.secondaryDark,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                              ),
                            )
                          : Container(color: AppColors.secondaryDark),
                    ),

                    // Gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // UPCOMING badge top left
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          '🔒 UPCOMING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Language badge top right
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          'Hindi Dubbed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    // Drama title + episode number at bottom
                    Positioned(
                      bottom: AppSpacing.md,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.dramaTitle.isNotEmpty)
                            Text(
                              controller.dramaTitle,
                              style: AppTypography.title.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.goldAccent,
                                shadows: [
                                  const Shadow(
                                    color: Colors.black,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            'Episode ${controller.episode.episodeNumber}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                              height: 1.1,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Countdown ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A0808), Color(0xFF150404)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Column(
                  children: [
                    Text(
                      'RELEASING IN',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.softGrey,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Obx(
                      () => Row(
                        children: [
                          _TimeUnit(
                            value: controller.days.value,
                            label: 'DAYS',
                          ),
                          _Colon(),
                          _TimeUnit(
                            value: controller.hours.value,
                            label: 'HRS',
                          ),
                          _Colon(),
                          _TimeUnit(
                            value: controller.minutes.value,
                            label: 'MINS',
                          ),
                          _Colon(),
                          _TimeUnit(
                            value: controller.seconds.value,
                            label: 'SECS',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Builder(
                      builder: (_) {
                        final date = controller.episode.releaseDate;
                        final formatted =
                            '${_dayName(date.weekday)}, ${date.day} '
                            '${_monthName(date.month)} ${date.year}  ·  '
                            '${date.hour.toString().padLeft(2, '0')}:'
                            '${date.minute.toString().padLeft(2, '0')}';
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.softGrey,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatted,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.softGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Telegram ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.secondaryDark,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔔 Get Notified When It Drops',
                      style: AppTypography.title.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Join our Telegram for instant alerts.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.softGrey,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (!AppUrls.isSafeUrl(AppUrls.telegram)) return;
                          final url = Uri.parse(AppUrls.telegram);
                          canLaunchUrl(url)
                              .then((can) {
                                if (can) {
                                  launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              })
                              .catchError((_) {});
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Join Telegram Channel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.medium,
                            ),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Back ──
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: AppColors.softGrey,
                  ),
                  label: Text(
                    'Back to Episode List',
                    style: AppTypography.body.copyWith(
                      color: AppColors.softGrey,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time Unit ─────────────────────────────────────────────────────────────────

class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;

  const _TimeUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A0A0A), Color(0xFF1C0505)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: AppColors.primaryRed.withValues(alpha: 0.4),
              ),
            ),
            child: Center(
              child: Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.softGrey.withValues(alpha: 0.8),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Colon ─────────────────────────────────────────────────────────────────────

class _Colon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        bottom: 20,
      ),
      child: Text(
        ':',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w300,
          color: AppColors.softGrey.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _dayName(int weekday) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[(weekday - 1).clamp(0, 6)];
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[(month - 1).clamp(0, 11)];
}
