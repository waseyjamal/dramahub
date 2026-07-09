import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/utils/app_snackbar.dart';
import 'package:drama_hub/widgets/telegram_cta_button.dart';
import 'package:drama_hub/widgets/cas_native_ad_widget.dart';
import 'package:drama_hub/widgets/home/hero_slider.dart';
import 'package:drama_hub/widgets/home/drama_card.dart';
import 'package:drama_hub/widgets/home/continue_watching_card.dart';
import 'package:drama_hub/widgets/home/latest_episodes_row.dart';
import 'package:drama_hub/widgets/home/coming_soon_row.dart';
import 'package:drama_hub/widgets/home/new_dramas_row.dart';
import 'package:drama_hub/widgets/home/home_skeleton_loader.dart';
import 'package:drama_hub/widgets/home/home_search_bar.dart';

/// Home screen
///
/// Main landing screen with hero banner, search, and drama grid.
/// All widget classes extracted to lib/widgets/home/ for maintainability.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _timer;

  // NOTE: _currentPage removed from here — it now lives inside HeroSlider's
  // own State. setState() for dot indicator no longer touches HomeScreen.

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // loadLastWatched called once here, not on every build()
    Get.find<HomeController>().loadLastWatched();

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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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

  Future<void> _onRefresh(HomeController controller) async {
    await controller.loadDramas(forceRefresh: true);
    if (mounted) {
      AppSnackbar.success('✅ Updated', 'Drama list refreshed successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final controller = Get.find<HomeController>();

    // FIX #2 — Both controllers fetched ONCE here, outside any builder or Obx.
    // Passed into DramaCard as constructor params.
    // Previously: Get.find() was called inside _DramaCard.build() —
    // that meant 40+ hashmap lookups per grid rebuild.
    // Now: exactly 2 lookups total, regardless of how many cards are shown.
    final watchlistController = Get.find<WatchlistController>();

    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const HomeSkeletonLoader();
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
          child: GestureDetector(
            onTap: () => _dismissSearch(controller),
            behavior: HitTestBehavior.translucent,
            child: RefreshIndicator(
              onRefresh: () => _onRefresh(controller),
              color: AppColors.primaryRed,
              backgroundColor: AppColors.cardBackground,
              child: CustomScrollView(
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
                        const SizedBox(height: 8),

                        // Hero Slider
                        // FIX #1 — HeroSlider is now a StatefulWidget.
                        // _currentPage lives inside it. Only the dot row
                        // repaints on auto-scroll — HomeScreen is unaffected.
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

                        // Continue Watching
                        Obx(
                          () => controller.lastDramaId.value.isNotEmpty
                              ? RepaintBoundary(
                                  child: ContinueWatchingCard(
                                    controller: controller,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        // Latest Episodes
                        RepaintBoundary(
                          child: LatestEpisodesRow(controller: controller),
                        ),

                        // New Dramas
                        RepaintBoundary(
                          child: NewDramasRow(controller: controller),
                        ),

                        // Coming Soon
                        RepaintBoundary(
                          child: ComingSoonRow(controller: controller),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Search Bar
                        HomeSearchBar(
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

                        const CasNativeAdWidget(screenKey: 'home_screen'),
                        const SizedBox(height: AppSpacing.md),
                      ]),
                    ),
                  ),

                  // Drama grid — SliverGrid for true lazy rendering
                  // FIX #2 — homeController and watchlistController fetched
                  // once above in build(), then passed into each DramaCard.
                  // Zero Get.find() calls inside the builder or the card.
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
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final drama = controller.filteredDramas[index];
                            return RepaintBoundary(
                              child: DramaCard(
                                drama: drama,
                                onTap: () => controller.goToEpisodes(drama),
                                homeController: controller,
                                watchlistController: watchlistController,
                              ),
                            );
                          },
                          childCount: controller.filteredDramas.length,
                        ),
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