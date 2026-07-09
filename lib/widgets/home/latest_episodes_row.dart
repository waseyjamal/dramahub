import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// Horizontal row showing the latest released episode from each drama.
/// Fetched asynchronously by HomeController after dramas load.
/// Hidden automatically when latestEpisodes list is empty.
/// Zero logic changes from original — pure file move.
class LatestEpisodesRow extends StatelessWidget {
  final HomeController controller;
  const LatestEpisodesRow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final episodes = controller.latestEpisodes;
      if (episodes.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              '🆕 Latest Episodes',
              style: AppTypography.title.copyWith(fontSize: 18),
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemExtent: 212.0,
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final item = episodes[index];
                final episode = item['episode'] as EpisodeModel;
                final drama = item['drama'] as DramaModel;

                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.goToEpisodes(drama);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      boxShadow: AppShadows.cardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: drama.bannerImage.isNotEmpty
                                  ? drama.bannerImage
                                  : drama.posterImage,
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              memCacheHeight: 260,
                              fadeInDuration: Duration.zero,
                              placeholder: (context, url) =>
                                  Container(color: AppColors.secondaryDark),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.secondaryDark,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                  stops: [0.4, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: AppSpacing.sm,
                            left: AppSpacing.sm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
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
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.goldAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Episode ${episode.episodeNumber}',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      );
    });
  }
}