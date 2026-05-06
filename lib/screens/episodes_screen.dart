import 'package:drama_hub/utils/constants.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:drama_hub/controllers/episodes_controller.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/widgets/animated_widgets.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// Episodes screen
class EpisodesScreen extends GetView<EpisodesController> {
  const EpisodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.selectedDrama.title),
        centerTitle: true,
      ),
      body: Obx(() {
        // ✅ 5.12 — Obx only for loading/error states
        // Header, banner, description are non-reactive — don't need Obx
        if (controller.isLoading.value) return const _EpisodesSkeletonLoader();
        if (!controller.hasInternet.value) return _buildNoInternet();
        if (controller.hasError.value) return _buildError();

        // Content body — static parts outside Obx
        return _buildContent();
      }),
    );
  }

  Widget _buildNoInternet() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 72, color: Colors.white24),
          const SizedBox(height: 20),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => controller.loadEpisodes(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: Colors.white24),
          const SizedBox(height: 20),
          const Text(
            'Something Went Wrong',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.errorMessage.value,
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => controller.loadEpisodes(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // In _buildContent(), replace _EpisodeGrid inside CustomScrollView:

  Widget _buildContent() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => controller.loadEpisodes(),
        color: AppColors.primaryRed,
        backgroundColor: AppColors.cardBackground,
        // ✅ 5.8 — CustomScrollView replaces SingleChildScrollView
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: AppSpacing.lg),
                  _DramaHeader(controller: controller),
                  const SizedBox(height: AppSpacing.md),
                  // title, description, promo card — all static, no Obx
                  Text(
                    controller.selectedDrama.title,
                    style: AppTypography.headlineMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All Episodes  •  ${controller.selectedDrama.releaseYear}  •  ${controller.selectedDrama.genre}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.softGrey,
                    ),
                  ),
                  if (controller.selectedDrama.description.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        boxShadow: AppShadows.cardShadow,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        controller.selectedDrama.description,
                        style: AppTypography.body.copyWith(
                          color: AppColors.softGrey,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  if (controller.selectedDrama.id ==
                      AppConstants.premiumDramaId)
                    const _MembershipPromoCard(),
                  const SizedBox(height: AppSpacing.xl),
                  const _SearchBar(),
                  const SizedBox(height: AppSpacing.xl),
                ]),
              ),
            ),

            // ✅ 5.8 + 5.12 — SliverGrid with Obx ONLY around the episode list
            Obx(() {
              if (controller.filteredEpisodes.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📺', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        const Text(
                          'No Episodes Found',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Episodes are coming soon. Stay tuned!',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.667,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final episode = controller.filteredEpisodes[index];
                    return _EpisodeCard(
                      episode: episode,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (episode.isPremium) {
                          Get.toNamed(AppRoutes.premium);
                        } else {
                          controller.openEpisode(episode);
                        }
                      },
                    );
                  }, childCount: controller.filteredEpisodes.length),
                ),
              );
            }),

            const SliverPadding(
              padding: EdgeInsets.only(bottom: AppSpacing.xl),
              sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodesSkeletonLoader extends StatelessWidget {
  const _EpisodesSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: const Color(0xFF2E2E2E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Banner skeleton
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            // Title skeleton
            Container(
              height: 24,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 24),
            // Search skeleton
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 24),
            // Episode grid skeleton
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.667,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 6,
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drama header with hero banner
class _DramaHeader extends StatelessWidget {
  final EpisodesController controller;

  const _DramaHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final drama = controller.selectedDrama;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: drama.bannerImage,
                fit: BoxFit.cover,
                memCacheWidth: 1920,
                memCacheHeight: 1080,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => Container(
                  color: AppColors.cardBackground,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.cardBackground,
                  child: const Icon(Icons.error_outline, size: 48),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.goldAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      drama.rating.toStringAsFixed(1),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Membership promo card
class _MembershipPromoCard extends StatelessWidget {
  const _MembershipPromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch Premium Episodes',
                  style: AppTypography.title.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Unlock all content with premium access',
                  style: AppTypography.body.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ad-free experience',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.goldAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              FirebaseAnalytics.instance.logEvent(
                name: 'premium_tapped',
                parameters: {'drama_id': 'arafta'},
              );
              Get.toNamed(AppRoutes.premium);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ),
            child: const Text('Go Premium'),
          ),
        ],
      ),
    );
  }
}

/// Search episode bar
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EpisodesController>();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: TextField(
        onChanged: controller.filterEpisodes,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Search episode...',
          hintStyle: AppTypography.body.copyWith(color: AppColors.softGrey),
          prefixIcon: const Icon(Icons.search, color: AppColors.softGrey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final EpisodeModel episode;
  final VoidCallback onTap;

  const _EpisodeCard({required this.episode, required this.onTap});

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
              Positioned.fill(
                child: episode.thumbnailImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: episode.thumbnailImage,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        memCacheWidth: 800,
                        memCacheHeight: 1200,
                        fadeInDuration: Duration.zero,
                        placeholder: (context, url) => Container(
                          color: AppColors.secondaryDark,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.cardBackground,
                                AppColors.secondaryDark,
                              ],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.cardBackground,
                              AppColors.secondaryDark,
                            ],
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
                      stops: [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              if (episode.thumbnailImage.isEmpty)
                Positioned(
                  top: AppSpacing.xl,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'EP ${episode.episodeNumber}',
                      style: AppTypography.headlineMedium.copyWith(
                        fontSize: 32,
                        color: AppColors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _StatusBadge(episode: episode),
              ),
              if (episode.isPremium)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Icon(
                        Icons.lock,
                        color: AppColors.primaryRed,
                        size: 48,
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
                      episode.title,
                      style: AppTypography.title.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.durationMinutes > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${episode.durationMinutes} min',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.softGrey,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

/// Status badge for episodes
class _StatusBadge extends StatelessWidget {
  final EpisodeModel episode;

  const _StatusBadge({required this.episode});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    bool isNewBadge = false;

    if (episode.isPremium) {
      label = 'PREMIUM';
      color = AppColors.primaryRed;
    } else if (episode.isUpcoming) {
      label = 'UPCOMING';
      color = AppColors.softGrey;
    } else if (episode.isNew && !episode.isUpcoming) {
      label = 'NEW';
      color = AppColors.goldAccent;
      isNewBadge = true;
    } else {
      return const SizedBox.shrink();
    }

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );

    if (isNewBadge) {
      return PulsingBadge(child: badge);
    }

    return badge;
  }
}
