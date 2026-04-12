import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/services/video_service.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/utils/app_snackbar.dart';

/// Controller for Video screen
class VideoController extends GetxController {
  final AdService _adService = Get.find<AdService>();
  final VideoService _videoService = Get.find<VideoService>();

  late EpisodeModel episode;

  // ✅ Drama info passed from EpisodesController for display in video screen
  String dramaTitle = '';
  String dramaBanner = '';

  // Download unlock state (session-based)
  final RxBool isDownloadUnlocked = false.obs;

  // Rewarded ad loading state
  final RxBool isRewardLoading = false.obs;

  // WebView loading state
  final RxBool isVideoLoading = true.obs;

  // Player initialized state
  // false = show thumbnail + play button
  // true  = show WebView player
  final RxBool isPlayerInitialized = false.obs;

  final RxBool hasVideoError = false.obs;

  @override
  void onInit() {
    super.onInit();

    // ✅ 3.2 — Safe cast with null check (was hard cast — LateInitializationError if null)
    final args = Get.arguments;
    if (args == null) {
      Future.microtask(() => Get.back());
      return;
    }
    if (args is EpisodeModel) {
      // ✅ backward compat — old callers passing just episode still work
      episode = args;
      dramaTitle = '';
      dramaBanner = '';
    } else if (args is Map) {
      final ep = args['episode'];
      if (ep == null || ep is! EpisodeModel) {
        Future.microtask(() => Get.back());
        return;
      }
      episode = ep;
      dramaTitle = args['dramaTitle'] ?? '';
      dramaBanner = args['dramaBanner'] ?? ''; // ✅ drama banner for thumbnail
    } else {
      Future.microtask(() => Get.back());
      return;
    }
    _videoService.enableSecureMode();
  }

  @override
  void onClose() {
    _videoService.disableSecureMode();
    super.onClose();
  }

  /// Unlocks download via rewarded ad (if enabled), or directly if ads disabled/unavailable
  Future<void> unlockDownload() async {
    if (isRewardLoading.value) return;
    try {
      isRewardLoading.value = true;
      await _adService.showRewardedForScreen(
        'video_screen',
        onRewarded: () {
          isDownloadUnlocked.value = true;
        },
        onNotAvailable: () {
          // Ad disabled or not loaded — unlock directly, no gate
          isDownloadUnlocked.value = true;
        },
      );
    } catch (e) {
      debugPrint('Rewarded ad error: $e');
      // Even on error, don't block the user
      isDownloadUnlocked.value = true;
    } finally {
      isRewardLoading.value = false;
    }
  }

  /// Navigates to download screen
  /// Uses episode.watchUrl pre-built from videoId
  Future<void> launchDownload() async {
    if (!isDownloadUnlocked.value) return;

    if (episode.watchUrl.isEmpty) {
      AppSnackbar.error(
        'Download Unavailable',
        'Download link for this episode is not available yet.',
      );
      return;
    }

    Get.toNamed(
      AppRoutes.download,
      arguments: {'episode': episode, 'watchUrl': episode.watchUrl},
    );
  }
}
