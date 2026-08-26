import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/widgets/home/drama_card.dart';

/// Category screen — shows all dramas filtered by category.
/// Reused for Turkish, Korean and World Series.
/// Receives arguments: { 'category': 'turkish', 'label': 'Turkish Dramas', 'flag': '🇹🇷' }
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final String _category;
  late final String _label;
  late final String _flag;
  late final HomeController _homeController;

  final TextEditingController _searchController = TextEditingController();
  final RxList<DramaModel> _filtered = <DramaModel>[].obs;
  final RxBool _isSearching = false.obs;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _category = args['category'] as String;
    _label = args['label'] as String;
    _flag = args['flag'] as String;

    _homeController = Get.find<HomeController>();

    // ── Reactive listener — re-filters whenever allDramas changes ─────────
    // Fixes stale-data bug: if user pulls-to-refresh on Home while this
    // screen is on the stack, the list updates automatically.
    ever(_homeController.allDramas, (_) => _applyFilter());

    _searchController.addListener(_applyFilter);
    _applyFilter();
  }

  void _applyFilter() {
    final source = _homeController.getDramasByCategory(_category);
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) {
      _isSearching.value = false;
      _filtered.assignAll(source);
    } else {
      _isSearching.value = true;
      _filtered.assignAll(
        source.where((d) => d.title.toLowerCase().contains(q)).toList(),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchlistController = Get.find<WatchlistController>();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '$_flag $_label',
                      style: AppTypography.title.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Search bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryDark,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTypography.body.copyWith(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Search $_label...',
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
                      suffixIcon: Obx(
                        () => _isSearching.value
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.softGrey,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Drama grid ────────────────────────────────────────────────
              Expanded(
                child: Obx(() {
                  final dramas = _filtered;

                  if (dramas.isEmpty) {
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
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.667,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: dramas.length,
                    itemBuilder: (context, index) {
                      final drama = dramas[index];
                      return RepaintBoundary(
                        child: DramaCard(
                          drama: drama,
                          onTap: () => _homeController.goToEpisodes(drama),
                          homeController: _homeController,
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
    );
  }
}
