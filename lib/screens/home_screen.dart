import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/utils/app_snackbar.dart';
import 'package:drama_hub/widgets/telegram_cta_button.dart';
import 'package:drama_hub/widgets/yandex_banner_ad_widget.dart';
import 'package:drama_hub/widgets/home/hero_slider.dart';
import 'package:drama_hub/widgets/home/drama_card.dart';
import 'package:drama_hub/widgets/home/continue_watching_card.dart';
import 'package:drama_hub/widgets/home/latest_episodes_row.dart';
import 'package:drama_hub/widgets/home/coming_soon_row.dart';
import 'package:drama_hub/widgets/home/new_dramas_row.dart';
import 'package:drama_hub/widgets/home/home_skeleton_loader.dart';
import 'package:drama_hub/widgets/home/home_search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _overlaySearchController = TextEditingController();
  final FocusNode _overlayFocusNode = FocusNode();
  Timer? _timer;

  // ── Search overlay animation ──────────────────────────────────────────────
  late final AnimationController _searchAnimController;
  late final Animation<double> _searchFadeAnim;
  late final Animation<Offset> _searchSlideAnim;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    Get.find<HomeController>().loadLastWatched();

    Future.delayed(const Duration(seconds: 2), () {
      AdService.instance.showInterstitialForScreen('home_screen');
    });

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _timer == null) {
        _timer?.cancel();
        return;
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

    // Search overlay animation — 280ms feels instant but not abrupt
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _searchFadeAnim = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Slides up from 6% below — subtle, not theatrical
    _searchSlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _searchAnimController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _overlaySearchController.dispose();
    _overlayFocusNode.dispose();
    _searchAnimController.dispose();
    super.dispose();
  }

  // ── Enter search mode ─────────────────────────────────────────────────────
  void _enterSearch() {
    final controller = Get.find<HomeController>();
    _overlaySearchController.text = _searchController.text;
    controller.isSearching.value = true;
    _searchAnimController.forward();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _overlayFocusNode.requestFocus();
    });
  }

  // ── Exit search mode — only called intentionally ──────────────────────────
  void _exitSearch() {
    final controller = Get.find<HomeController>();
    _overlayFocusNode.unfocus();
    _overlaySearchController.clear();
    _searchController.clear();
    controller.filterDramas('');
    controller.isSearching.value = false;
    _searchAnimController.reverse();
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

  Future<void> _onRefresh(HomeController controller) async {
    await controller.loadDramas(forceRefresh: true);
    if (mounted) {
      AppSnackbar.success('✅ Updated', 'Drama list refreshed successfully');
    }
  }

  // ── Full-screen search overlay ────────────────────────────────────────────
  Widget _buildSearchOverlay(
    HomeController controller,
    WatchlistController watchlistController,
  ) {
    return FadeTransition(
      opacity: _searchFadeAnim,
      child: SlideTransition(
        position: _searchSlideAnim,
        child: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SafeArea(
            child: Column(
              children: [
                // ── Pinned search bar + Cancel ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryDark,
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
                          ),
                          child: TextField(
                            controller: _overlaySearchController,
                            focusNode: _overlayFocusNode,
                            autofocus: true,
                            onChanged: (value) {
                              _searchController.text = value;
                              controller.filterDramas(value);
                            },
                            style: AppTypography.body.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search drama name...',
                              hintStyle: AppTypography.body.copyWith(
                                color: AppColors.softGrey,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.softGrey,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      GestureDetector(
                        onTap: _exitSearch,
                        child: Text(
                          'Cancel',
                          style: AppTypography.body.copyWith(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Results ─────────────────────────────────────────────────
                Expanded(
                  child: Obx(() {
                    final results = controller.filteredDramas;

                    if (results.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No dramas found',
                              style: AppTypography.title.copyWith(
                                color: Colors.white54,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different name',
                              style: AppTypography.body.copyWith(
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.667,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final drama = results[index];
                        return RepaintBoundary(
                          child: DramaCard(
                            drama: drama,
                            onTap: () => controller.goToEpisodes(drama),
                            homeController: controller,
                            watchlistController: watchlistController,
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Normal home content ───────────────────────────────────────────────────
  Widget _buildHomeContent(
    HomeController controller,
    WatchlistController watchlistController,
  ) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _onRefresh(controller),
        color: AppColors.primaryRed,
        backgroundColor: AppColors.cardBackground,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Obx(
                    () => controller.isOfflineCached.value
                        ? _buildOfflineBanner()
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),

                  Obx(
                    () => controller.heroSliderDramas.isNotEmpty
                        ? RepaintBoundary(
                            child: HeroSlider(
                              dramas: controller.heroSliderDramas,
                              controller: controller,
                              pageController: _pageController,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Obx(
                    () => controller.lastDramaId.value.isNotEmpty
                        ? RepaintBoundary(
                            child: ContinueWatchingCard(controller: controller),
                          )
                        : const SizedBox.shrink(),
                  ),

                  RepaintBoundary(
                    child: LatestEpisodesRow(controller: controller),
                  ),

                  RepaintBoundary(child: NewDramasRow(controller: controller)),

                  RepaintBoundary(child: ComingSoonRow(controller: controller)),

                  const SizedBox(height: AppSpacing.xl),

                  // Search bar — tapping enters search mode
                  HomeSearchBar(
                    controller: controller,
                    textController: _searchController,
                    focusNode: _searchFocusNode,
                    onFocused: _enterSearch,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      '🎬 All Dramas',
                      style: AppTypography.title.copyWith(fontSize: 18),
                    ),
                  ),

                  const YandexBannerAdWidget(screenKey: 'home_screen'),
                  const SizedBox(height: AppSpacing.md),
                ]),
              ),
            ),

            Obx(
              () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.667,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final drama = controller.filteredDramas[index];
                    return RepaintBoundary(
                      child: DramaCard(
                        drama: drama,
                        onTap: () => controller.goToEpisodes(drama),
                        homeController: controller,
                        watchlistController: watchlistController,
                      ),
                    );
                  }, childCount: controller.filteredDramas.length),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = Get.find<HomeController>();
    final watchlistController = Get.find<WatchlistController>();

    return Scaffold(
      body: Obx(() {
        // ── Loading state ─────────────────────────────────────────────────
        if (controller.isLoading.value) {
          return const HomeSkeletonLoader();
        }

        // ── No internet, no cache ─────────────────────────────────────────
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

        // ── Error state ───────────────────────────────────────────────────
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

        // ── Main content — Stack: home behind, search overlay on top ──────
        return PopScope(
          // When search is active, back button exits search instead of
          // navigating away from the home screen
          canPop: !controller.isSearching.value,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && controller.isSearching.value) {
              _exitSearch();
            }
          },
          child: Stack(
            children: [
              // Layer 1 — Normal home (always built, stays alive in memory)
              _buildHomeContent(controller, watchlistController),

              // Layer 2 — Search overlay (animated in/out over the top)
              if (controller.isSearching.value)
                _buildSearchOverlay(controller, watchlistController),
            ],
          ),
        );
      }),
    );
  }
}
