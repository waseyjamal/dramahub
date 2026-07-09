import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// "Continue Watching" card shown when the user has a previously
/// watched drama saved in SharedPreferences.
///
/// Only rendered when lastDramaId is non-empty — the parent Obx in
/// HomeScreen guards this widget's visibility.
///
/// FIX — Obx scope reduced from wrapping the entire card to wrapping
/// only the three reactive fields that actually change:
///   • lastDramaBanner  → drives the thumbnail image URL
///   • lastDramaTitle   → drives the title text
///   • lastEpisodeNumber → drives the episode label
///
/// BEFORE: entire card including static border, margins, chevron icon,
/// and "▶ Continue Watching" label rebuilt on any observable change.
///
/// AFTER: static card shell is built once and never rebuilt.
/// Only the inner content column — the three reactive fields — is
/// inside Obx and rebuilds when those values change.
class ContinueWatchingCard extends StatelessWidget {
  final HomeController controller;
  const ContinueWatchingCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Static card shell — built once, never rebuilt by Obx.
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          controller.goToLastWatchedEpisode();
        },
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: AppShadows.cardShadow,
            border: Border.all(
              color: AppColors.primaryRed.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              // FIX — Obx wraps only the image URL read.
              // The ClipRRect shape and dimensions are static.
              Obx(() => ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: controller.lastDramaBanner.value,
                      width: 100,
                      height: 70,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      memCacheHeight: 280,
                      fadeInDuration: Duration.zero,
                      errorWidget: (c, u, e) => Container(
                        width: 100,
                        height: 70,
                        color: AppColors.secondaryDark,
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  )),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Static — never changes
                    const Text(
                      '▶ Continue Watching',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    // FIX — Obx wraps only the two reactive text fields.
                    Obx(() => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              controller.lastDramaTitle.value,
                              style: AppTypography.title.copyWith(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Episode ${controller.lastEpisodeNumber.value}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.goldAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              ),
              // Static — never changes
              const Icon(Icons.chevron_right, color: Colors.white54),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}