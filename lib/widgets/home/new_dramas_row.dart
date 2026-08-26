import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// Horizontal row showing the most recently added dramas to Drama Hub.
/// Sorted by addedOn timestamp descending — newest drama appears first.
/// Shows maximum 10 dramas. Hidden automatically when newDramas list is empty.
/// Style matches ComingSoonRow exactly — same card size, same header style.
class NewDramasRow extends StatelessWidget {
  final HomeController controller;
  const NewDramasRow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dramas = controller.newDramas;
      if (dramas.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primaryRed, AppColors.goldAccent],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'New Dramas',
                      style: AppTypography.title.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.newDramas),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.softGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.softGrey,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 182,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: dramas.length,
              itemBuilder: (context, index) {
                final drama = dramas[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.goToEpisodes(drama);
                  },
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        // Poster
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.large),
                          child: CachedNetworkImage(
                            imageUrl: drama.posterImage,
                            width: 130,
                            height: 182,
                            fit: BoxFit.cover,
                            memCacheWidth: 260,
                            memCacheHeight: 364,
                            fadeInDuration: Duration.zero,
                            placeholder: (context, url) =>
                                Container(color: AppColors.cardBackground),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.cardBackground,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                        // Gradient overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 182,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.large,
                            ),
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
                        ),
                        // NEW badge — top left
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'NEW',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Title + genre
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  drama.title,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
