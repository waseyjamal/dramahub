import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/widgets/animated_widgets.dart';
import 'package:drama_hub/utils/app_snackbar.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/widgets/telegram_cta_button.dart';

/// Home screen
///
/// Main landing screen with hero banner, search, and drama grid
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// ✅ #5 — AutomaticKeepAliveClientMixin keeps Home tab alive without full rebuild
class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _currentPage = 0;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true; // ✅ #5

  @override
  void initState() {
    super.initState();

    // ✅ 4.1 — loadLastWatched moved here from build()
    // Was firing after EVERY rebuild via addPostFrameCallback — constant SharedPreferences reads
    // Now called once on widget creation
    Get.find<HomeController>().loadLastWatched();

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _timer == null) {
        _timer?.cancel();
      }
      final controller = Get.find<HomeController>();
      if (controller.heroSliderDramas.length > 1) {
        if (_pageController.hasClients) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
    // ✅ 3.6 — ever() with empty callback removed (was memory leak)
  }

  @override
  void dispose() {
    // ✅ 4.3 — Cancel timer FIRST before disposing pageController
    // Prevents timer firing on an already-disposed controller in the gap between
    // cancel() call and garbage collection
    _timer?.cancel();
    _timer =
        null; // ✅ Null it out so any in-flight callback sees null and stops
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Dismiss keyboard and clear search when tapping outside search bar
  void _dismissSearch(HomeController controller) {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      _searchController.clear();
      controller.filterDramas('');
    }
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            'Offline — showing cached content',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ #9 — refresh with snackbar feedback
  Future<void> _onRefresh(HomeController controller) async {
    await controller.loadDramas(forceRefresh: true);
    if (mounted) {
      AppSnackbar.success('✅ Updated', 'Drama list refreshed successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ #5 — required for KeepAlive
    final controller = Get.find<HomeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drama Hub'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const _HomeSkeletonLoader();
        }

        if (!controller.hasInternet.value &&
            !controller.isOfflineCached.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 80,
                  color: Colors.white24,
                ),
                const SizedBox(height: 24),
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
                  'Please check your connection and try again',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => controller.loadDramas(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ✅ #1 — proper error state instead of blank screen
        if (controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.white24,
                ),
                const SizedBox(height: 24),
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
                  onPressed: () => controller.loadDramas(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          // GestureDetector wraps entire body — tap anywhere outside search = dismiss
          child: GestureDetector(
            onTap: () => _dismissSearch(controller),
            behavior: HitTestBehavior.translucent,
            // REMOVE the entire SingleChildScrollView wrapping in the content body
            // and replace with CustomScrollView

            // In _HomeScreenState build(), replace the RefreshIndicator child:
            child: RefreshIndicator(
              onRefresh: () => _onRefresh(controller),
              color: AppColors.primaryRed,
              backgroundColor: AppColors.cardBackground,
              child: CustomScrollView(
                // ✅ 5.8 — replaces SingleChildScrollView
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Offline banner
                        Obx(
                          () => controller.isOfflineCached.value
                              ? _buildOfflineBanner()
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Hero Slider
                        Obx(
                          () => controller.heroSliderDramas.isNotEmpty
                              ? RepaintBoundary(
                                  child: _HeroSlider(
                                    dramas: controller.heroSliderDramas,
                                    controller: controller,
                                    pageController: _pageController,
                                    currentPage: _currentPage,
                                    onPageChanged: (index) {
                                      setState(
                                        () => _currentPage =
                                            index %
                                            controller.heroSliderDramas.length,
                                      );
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // Continue Watching
                        Obx(
                          () => controller.lastDramaId.value.isNotEmpty
                              ? RepaintBoundary(
                                  child: _ContinueWatchingCard(
                                    controller: controller,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        // Latest Episodes
                        RepaintBoundary(
                          child: _LatestEpisodesRow(controller: controller),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // Search Bar
                        _SearchBar(
                          controller: controller,
                          textController: _searchController,
                          focusNode: _searchFocusNode,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            '🎬 All Dramas',
                            style: AppTypography.title.copyWith(fontSize: 18),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  // ✅ 5.8 — SliverGrid replaces shrinkWrap GridView
                  // Now ONLY visible items are built — true lazy rendering restored
                  Obx(
                    () => SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.667,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final drama = controller.filteredDramas[index];
                          return RepaintBoundary(
                            // ✅ 5.10
                            child: _DramaCard(
                              drama: drama,
                              onTap: () => controller.goToEpisodes(drama),
                            ),
                          );
                        }, childCount: controller.filteredDramas.length),
                      ),
                    ),
                  ),

                  // Load More + Telegram CTA + bottom padding
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Obx(
                          () => controller.hasMoreDramas.value
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.lg,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      controller.loadMoreDramas();
                                    },
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: const Text('Load More Dramas'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 14,
                                      ),
                                      side: BorderSide(
                                        color: AppColors.primaryRed.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const TelegramCTAButton(),
                        const SizedBox(height: AppSpacing.xl),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HomeSkeletonLoader extends StatelessWidget {
  const _HomeSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: const Color(0xFF2E2E2E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (_, i) => Container(
                  width: 200,
                  height: 130,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.667,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 4,
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

/// Hero banner section with featured drama
class _HeroSlider extends StatelessWidget {
  final List<DramaModel> dramas;
  final HomeController controller;
  final PageController pageController;
  final int currentPage;
  final Function(int) onPageChanged;

  const _HeroSlider({
    required this.dramas,
    required this.controller,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: 99999,
            itemBuilder: (context, index) {
              final drama = dramas[index % dramas.length];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
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
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.cardBackground,
                            child: const Icon(Icons.error_outline, size: 48),
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
                      Positioned(
                        top: AppSpacing.md,
                        left: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: Text(
                            drama.genre.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: AppSpacing.lg,
                        left: AppSpacing.lg,
                        right: AppSpacing.xxl * 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              drama.title,
                              style: AppTypography.headlineMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${drama.releaseYear} • ${drama.totalEpisodes} Episodes',
                              style: AppTypography.body.copyWith(
                                color: AppColors.goldAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: PulsingPlayButton(
                          onTap: () => controller.goToEpisodes(drama),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            dramas.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: currentPage == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? AppColors.primaryRed
                    : AppColors.softGrey.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Search bar widget
/// TextEditingController + FocusNode passed from parent for dismiss control
class _SearchBar extends StatelessWidget {
  final HomeController controller;
  final TextEditingController textController;
  final FocusNode focusNode;

  const _SearchBar({
    required this.controller,
    required this.textController,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: TextField(
        controller: textController,
        focusNode: focusNode,
        onChanged: controller.filterDramas,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Search drama name...',
          hintStyle: AppTypography.body.copyWith(color: AppColors.softGrey),
          prefixIcon: const Icon(Icons.search, color: AppColors.softGrey),
          suffixIcon: Obx(
            () =>
                controller.filteredDramas.length != controller.allDramas.length
                ? InkWell(
                    onTap: () {
                      textController.clear();
                      controller.filterDramas('');
                      focusNode.unfocus();
                    },
                    borderRadius: BorderRadius.circular(32),
                    child: const Icon(Icons.close, color: AppColors.softGrey),
                  )
                : const SizedBox.shrink(),
          ),
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

/// Individual drama card
class _DramaCard extends StatelessWidget {
  final DramaModel drama;
  final VoidCallback onTap;

  const _DramaCard({required this.drama, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final watchlistController = Get.find<WatchlistController>();
    final homeController = Get.find<HomeController>(); // ✅ for progress bar #8

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
              // Poster image
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

              // Bottom gradient
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

              // Top-left rating badge ★
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

              // Top-right heart button
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Obx(() {
                  final isLiked = watchlistController.isInWatchlist(drama.id);
                  return InkWell(
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
                        color: isLiked ? AppColors.primaryRed : Colors.white70,
                        size: 18,
                      ),
                    ),
                  );
                }),
              ),

              // ✅ #8 — Netflix-style progress bar for last watched drama
              Obx(() {
                final isLastWatched =
                    homeController.lastDramaId.value == drama.id;
                final episodeCount = drama.totalEpisodes;
                final lastEp = homeController.lastEpisodeNumber.value;
                if (!isLastWatched || episodeCount == 0) {
                  return const SizedBox.shrink();
                }
                final progress = (lastEp / episodeCount).clamp(0.0, 1.0);
                return Positioned(
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
                );
              }),

              // Bottom-left content
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

class _ContinueWatchingCard extends StatelessWidget {
  final HomeController controller;
  const _ContinueWatchingCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
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
                ClipRRect(
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
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '▶ Continue Watching',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Latest Episodes Row
/// Shows real latest episodes fetched across all dramas from controller
class _LatestEpisodesRow extends StatelessWidget {
  final HomeController controller;
  const _LatestEpisodesRow({required this.controller});

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
