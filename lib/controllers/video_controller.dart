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

  // WebView loading state
  final RxBool isVideoLoading = true.obs;

  // Player initialized state
  // false = show thumbnail + play button
  // true  = show WebView player
  final RxBool isPlayerInitialized = false.obs;
  final RxBool hasVideoError = false.obs;

  // Download navigation loading state
  final RxBool isDownloadLoading = false.obs;

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
      dramaBanner = args['dramaBanner'] ?? '';
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
