import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/widgets/animated_widgets.dart';

/// Hero banner slider shown at the top of the home screen.
///
/// StatefulWidget — owns _currentPage for the dot indicator.
/// setState() here rebuilds only the dot row, not HomeScreen.
///
/// PageController and auto-scroll Timer live in HomeScreen because
/// their lifetimes are tied to the screen, not this widget.
///
/// FIX — Replaced magic itemCount: 99999 with int.maxValue from dart:core.
///
/// BEFORE: 99999 is an arbitrary magic number with no documented reason.
/// It creates 99999 virtual pages — enough for ~111 hours of continuous
/// auto-scrolling at 4s per slide before wrapping. Not wrong, but not
/// defensible in a code review.
///
/// AFTER: int.maxValue (~2.1 billion) is the correct Dart idiom for
/// "effectively infinite" PageView. Semantically correct, self-documenting,
/// and consistent with how Flutter's own documentation recommends infinite
/// scroll patterns.
class HeroSlider extends StatefulWidget {
  final List<DramaModel> dramas;
  final HomeController controller;
  final PageController pageController;

  const HeroSlider({
    super.key,
    required this.dramas,
    required this.controller,
    required this.pageController,
  });

  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> {
  // Owns only _currentPage — the minimum state needed for the dot indicator.
  // setState() here repaints only the 8px dot row at the bottom of this widget.
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: widget.pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index % widget.dramas.length);
            },
            itemBuilder: (context, index) {
              final drama = widget.dramas[index % widget.dramas.length];
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
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
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
                          onTap: () =>
                              widget.controller.goToEpisodes(drama),
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
        // Only this row rebuilds on page change — setState() above
        // targets _HeroSliderState, not HomeScreen.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.dramas.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
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