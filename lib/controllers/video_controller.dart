import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/services/video_service.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/utils/app_snackbar.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/episodes_controller.dart';

/// Controller for Video screen
class VideoController extends GetxController {
  final AdService _adService = Get.find<AdService>();
  final VideoService _videoService = Get.find<VideoService>();

  late EpisodeModel episode;

  // ✅ Drama info passed from EpisodesController for display in video screen
  String dramaTitle = '';
  String dramaBanner = '';

  // WebView loading state
  final RxBool isVideoLoading = true.obs;

  // Player initialized state
  // false = show thumbnail + play button
  // true  = show WebView player
  final RxBool isPlayerInitialized = false.obs;
  final RxBool hasVideoError = false.obs;
  final RxBool isCustomPlayer = false.obs;
  final RxString streamUrl = ''.obs;

  // Download navigation loading state
  final RxBool isDownloadLoading = false.obs;

  // ── New fields for video screen UI sections ──
  DramaModel? drama;
  List<EpisodeModel> allEpisodes = [];
  EpisodeModel? nextEpisode;
  List<DramaModel> similarDramas = [];

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args == null) {
      Future.microtask(() => Get.back());
      return;
    }
    if (args is EpisodeModel) {
      episode = args;
      isCustomPlayer.value = episode.isCustomPlayer;
      streamUrl.value = episode.streamUrl;
      dramaTitle = '';
      dramaBanner = '';
    } else if (args is Map) {
      final ep = args['episode'];
      if (ep == null || ep is! EpisodeModel) {
        Future.microtask(() => Get.back());
        return;
      }
      episode = ep;
      isCustomPlayer.value = episode.isCustomPlayer;
      streamUrl.value = episode.streamUrl;
      dramaTitle = args['dramaTitle'] ?? '';
      dramaBanner = args['dramaBanner'] ?? '';
    } else {
      Future.microtask(() => Get.back());
      return;
    }
    _videoService.enableSecureMode();
    _loadExtraData();
  }

  @override
  void onClose() {
    _videoService.disableSecureMode();
    super.onClose();
  }

  void _loadExtraData() {
    // Load all episodes and drama from EpisodesController if available
    try {
      final episodesCtrl = Get.find<EpisodesController>();
      allEpisodes = List<EpisodeModel>.from(episodesCtrl.allEpisodes)
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      drama = episodesCtrl.selectedDrama;
    } catch (_) {
      // EpisodesController not available — user came from history/home
      allEpisodes = [];
      drama = null;
    }

    // Find next episode
    if (allEpisodes.isNotEmpty) {
      final currentIndex = allEpisodes.indexWhere(
        (e) => e.episodeNumber == episode.episodeNumber,
      );
      if (currentIndex != -1 && currentIndex < allEpisodes.length - 1) {
        final next = allEpisodes[currentIndex + 1];
        nextEpisode = next.isReleased ? next : null;
      }
    }

    // Load similar dramas from HomeController
    try {
      final homeCtrl = Get.find<HomeController>();
      final allDramas = homeCtrl.allDramas;
      final currentGenre = drama?.genre ?? '';

      // Same genre first, excluding current drama
      final sameGenre = allDramas
          .where(
            (d) =>
                d.id != drama?.id &&
                d.genre.toLowerCase() == currentGenre.toLowerCase() &&
                d.isActive,
          )
          .toList();

      // Fill remaining with other dramas if needed
      final others = allDramas
          .where(
            (d) =>
                d.id != drama?.id &&
                d.genre.toLowerCase() != currentGenre.toLowerCase() &&
                d.isActive,
          )
          .toList();

      similarDramas = [...sameGenre, ...others].take(6).toList();
    } catch (_) {
      similarDramas = [];
    }
  }

  Future<void> goToNextEpisode() async {
    if (nextEpisode == null) return;
    final next = nextEpisode!;

    await _adService.showRewardedForScreen(
      'episodes_screen',
      onRewarded: () => _navigateToEpisode(next),
      onNotAvailable: () => _navigateToEpisode(next),
    );
  }

  void _navigateToEpisode(EpisodeModel ep) {
    Get.offAndToNamed(
      AppRoutes.video,
      arguments: {
        'episode': ep,
        'dramaTitle': dramaTitle,
        'dramaBanner': dramaBanner,
      },
    );
  }

  /// Navigates to download screen
  /// Shows rewarded ad first if enabled in config, then goes to DownloadScreen
  Future<void> goToDownload() async {
    if (isDownloadLoading.value) return;

    if (episode.watchUrl.isEmpty) {
      AppSnackbar.error(
        'Download Unavailable',
        'Download link for this episode is not available yet.',
      );
      return;
    }

    try {
      isDownloadLoading.value = true;

      await _adService.showRewardedForScreen(
        'video_screen',
        onRewarded: () {
          Get.toNamed(
            AppRoutes.download,
            arguments: {'episode': episode, 'watchUrl': episode.watchUrl},
          );
        },
        onNotAvailable: () {
          // Rewarded not available or disabled — go directly
          Get.toNamed(
            AppRoutes.download,
            arguments: {'episode': episode, 'watchUrl': episode.watchUrl},
          );
        },
      );
    } catch (e) {
      debugPrint('Download ad error: $e');
      // On any error — go directly, never block user
      Get.toNamed(
        AppRoutes.download,
        arguments: {'episode': episode, 'watchUrl': episode.watchUrl},
      );
    } finally {
      isDownloadLoading.value = false;
    }
  }
}
