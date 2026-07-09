import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// Individual drama card shown in the home screen grid.
///
/// Both controllers are received as constructor parameters — zero
/// Get.find() calls inside build(). See home_screen.dart for context.
///
/// FIX — Two separate Obx blocks (heart button + progress bar) merged
/// into one single Obx that reads all four reactive values together.
///
/// BEFORE: 2 Obx per card × 20 cards = 40 observers registered in the
/// GetX observer tree. Every watchlist change notified all 40.
///
/// AFTER: 1 Obx per card × 20 cards = 20 observers total.
/// The single Obx reads:
///   • watchlistController.watchlist    → drives heart icon state
///   • homeController.lastDramaId      → drives progress bar visibility
///   • homeController.lastEpisodeNumber → drives progress bar value
/// All four reads happen in one observer callback — same rebuild cost,
/// half the observer registrations.
class DramaCard extends StatelessWidget {
  final DramaModel drama;
  final VoidCallback onTap;
  final HomeController homeController;
  final WatchlistController watchlistController;

  const DramaCard({
    super.key,
    required this.drama,
    required this.onTap,
    required this.homeController,
    required this.watchlistController,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Stack(
            children: [
              // Poster image — static, no Obx needed
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: drama.posterImage,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  memCacheHeight: 900,
                  fadeInDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    color: AppColors.cardBackground,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.cardBackground,
                    child: const Icon(Icons.error_outline, size: 32),
                  ),
                ),
              ),

              // Bottom gradient — static, no Obx needed
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),

              // Rating badge — static, driven by drama model not observables
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    '★ ${drama.rating.toStringAsFixed(1)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // FIX — Single merged Obx for both heart button and progress bar.
              //
              // Previously two separate Obx widgets each registered their own
              // observer. Now one Obx reads all reactive values in one pass:
              //   isLiked        — from watchlistController.watchlist
              //   isLastWatched  — from homeController.lastDramaId
              //   lastEp         — from homeController.lastEpisodeNumber
              //
              // One observer fires when any of these change, rebuilds both
              // the heart icon and the progress bar together in one pass.
              // Net result: 50% fewer observer registrations across the grid.
              Obx(() {
                final isLiked = watchlistController.isInWatchlist(drama.id);
                final isLastWatched =
                    homeController.lastDramaId.value == drama.id;
                final episodeCount = drama.totalEpisodes;
                final lastEp = homeController.lastEpisodeNumber.value;
                final progress = episodeCount > 0 && isLastWatched
                    ? (lastEp / episodeCount).clamp(0.0, 1.0)
                    : 0.0;

                return Stack(
                  children: [
                    // Heart button — top right
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          watchlistController.toggleWatchlist(drama);
                        },
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isLiked
                                ? AppColors.primaryRed
                                : Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    // Progress bar — bottom, only visible for last watched drama
                    if (isLastWatched && episodeCount > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryRed,
                          ),
                          minHeight: 3,
                        ),
                      ),
                  ],
                );
              }),

              // Title + year — static, driven by drama model not observables
              Positioned(
                bottom: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      drama.title,
                      style: AppTypography.title.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      drama.releaseYear.toString(),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.goldAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}