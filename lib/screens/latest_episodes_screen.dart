import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';

class LatestEpisodesScreen extends StatelessWidget {
  const LatestEpisodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

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
          '🆕 Latest Episodes',
          style: AppTypography.title.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        final episodes = controller.allLatestEpisodes;
        if (episodes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.movie_outlined,
                  color: Colors.white24,
                  size: 64,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('No episodes available', style: AppTypography.body),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.667,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final item = episodes[index];
            final drama = item['drama'] as DramaModel;
            final episodeNumber = item['episodeNumber'] as int;
            final episodeDate = item['episodeDate'] as String;

            // Check if episode is new (within 48 hours)
            final isNew = () {
              try {
                final date = DateTime.parse(episodeDate);
                return DateTime.now().difference(date).inHours <= 48;
              } catch (_) {
                return false;
              }
            }();

            return _LatestEpisodeCard(
              drama: drama,
              episodeNumber: episodeNumber,
              isNew: isNew,
              onTap: () {
                HapticFeedback.lightImpact();
                controller.goToEpisodes(drama);
              },
            );
          },
        );
      }),
    );
  }
}

class _LatestEpisodeCard extends StatelessWidget {
  final DramaModel drama;
  final int episodeNumber;
  final bool isNew;
  final VoidCallback onTap;

  const _LatestEpisodeCard({
    required this.drama,
    required this.episodeNumber,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              // Poster image
              Positioned.fill(
                child: drama.posterImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: drama.posterImage,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        memCacheWidth: 400,
                        memCacheHeight: 600,
                        fadeInDuration: Duration.zero,
                        placeholder: (context, url) => Container(
                          color: AppColors.secondaryDark,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.secondaryDark,
                          child: const Icon(
                            Icons.movie_outlined,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(color: AppColors.secondaryDark),
              ),

              // Bottom gradient
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // NEW badge
              if (isNew)
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              // Episode number badge top right
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.goldAccent.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'EP $episodeNumber',
                    style: const TextStyle(
                      color: AppColors.goldAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Drama title at bottom
              Positioned(
                bottom: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Text(
                  drama.title,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    shadows: [const Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
