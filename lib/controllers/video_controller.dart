import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/services/download_service.dart';
import 'package:drama_hub/services/signing_service.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/utils/app_snackbar.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/episodes_controller.dart';
import 'package:drama_hub/widgets/vidswift_install_sheet.dart';

/// Controller for Video screen
class VideoController extends GetxController {
  final AdService _adService = Get.find<AdService>();

  late EpisodeModel episode;

  String dramaTitle = '';
  String dramaBanner = '';

  final RxBool isVideoLoading = true.obs;
  final RxBool isPlayerInitialized = false.obs;
  final RxBool hasVideoError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isCustomPlayer = false.obs;
  final RxString streamUrl = ''.obs;
  final RxBool isDownloadLoading = false.obs;

  // ── Extra data for video screen UI ──
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
      streamUrl.value = episode.usesMp4 ? episode.mp4Url : episode.streamUrl;
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
      streamUrl.value = episode.usesMp4 ? episode.mp4Url : episode.streamUrl;
      dramaTitle = args['dramaTitle'] ?? '';
      dramaBanner = args['dramaBanner'] ?? '';
    } else {
      Future.microtask(() => Get.back());
      return;
    }
    _loadExtraData();
  }

  /// Resolves signed stream URL — called by video_screen before player init.
  /// Returns signed URL if signing enabled, raw URL as fallback.
  Future<String> resolveStreamUrl() async {
    final rawUrl = episode.usesMp4 ? episode.mp4Url : episode.streamUrl;
    if (kDebugMode) {
      debugPrint(
        'resolveStreamUrl: dramaId=${episode.dramaId} ep=${episode.episodeNumber} mp4Url=${episode.mp4Url} streamUrl=${episode.streamUrl} usesMp4=${episode.usesMp4}',
      );
    }
    if (rawUrl.isEmpty) return rawUrl;

    if (!episode.isCustomPlayer) return rawUrl;

    return SigningService.instance.getStreamUrl(
      dramaId: episode.dramaId,
      episodeNumber: episode.episodeNumber,
      rawUrl: rawUrl,
    );
  }

  void _loadExtraData() {
    try {
      final episodesCtrl = Get.find<EpisodesController>();
      allEpisodes = List<EpisodeModel>.from(episodesCtrl.allEpisodes)
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      drama = episodesCtrl.selectedDrama;
    } catch (_) {
      allEpisodes = [];
      drama = null;
    }

    if (allEpisodes.isNotEmpty) {
      final currentIndex = allEpisodes.indexWhere(
        (e) => e.episodeNumber == episode.episodeNumber,
      );
      if (currentIndex != -1 && currentIndex < allEpisodes.length - 1) {
        final next = allEpisodes[currentIndex + 1];
        nextEpisode = next.isReleased ? next : null;
      }
    }

    try {
      final homeCtrl = Get.find<HomeController>();
      final allDramas = homeCtrl.allDramas;
      final currentGenre = drama?.genre ?? '';

      final sameGenre = allDramas
          .where(
            (d) =>
                d.id != drama?.id &&
                d.genre.toLowerCase() == currentGenre.toLowerCase() &&
                d.isActive,
          )
          .toList();

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

  /// Starts in-app download with signed URL (custom/MP4 episodes only)
  Future<void> goToDownload() async {
    if (isDownloadLoading.value) return;

    if (!episode.hasDownload) {
      AppSnackbar.error(
        'Download Unavailable',
        'Download link for this episode is not available yet.',
      );
      return;
    }

    try {
      isDownloadLoading.value = true;

      final signedUrl = await SigningService.instance.getDownloadUrl(
        dramaId: episode.dramaId,
        episodeNumber: episode.episodeNumber,
        rawUrl: episode.mp4Url,
      );

      await _adService.showRewardedForDownload(
        onRewarded: () async {
          final success = await DownloadService.instance.startDownload(
            episode: episode,
            dramaTitle: dramaTitle,
            mp4Url: signedUrl,
          );
          if (!success) {
            AppSnackbar.error(
              'Download Failed',
              'Could not start download. Please try again.',
            );
          }
        },
        onNotAvailable: () async {
          await DownloadService.instance.startDownload(
            episode: episode,
            dramaTitle: dramaTitle,
            mp4Url: signedUrl,
          );
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Download error: $e');
    } finally {
      isDownloadLoading.value = false;
    }
  }

  /// Shares YouTube URL to VidBlaze for downloading.
  Future<void> goToYoutubeDownload() async {
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
      await _adService.showRewardedForDownload(
        onRewarded: () => _handleVidblazShare(episode.watchUrl),
        onNotAvailable: () => _handleVidblazShare(episode.watchUrl),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('YouTube download error: $e');
      _handleVidblazShare(episode.watchUrl);
    } finally {
      isDownloadLoading.value = false;
    }
  }

  /// Shares Rumble URL to VidBlaze for downloading.
  Future<void> goToRumbleDownload() async {
    if (isDownloadLoading.value) return;

    if (episode.rumbleId.isEmpty) {
      AppSnackbar.error(
        'Download Unavailable',
        'Download link for this episode is not available yet.',
      );
      return;
    }

    try {
      isDownloadLoading.value = true;
      final url = 'https://rumble.com/embed/${episode.rumbleId}/';
      await _adService.showRewardedForDownload(
        onRewarded: () => _handleVidblazShare(url),
        onNotAvailable: () => _handleVidblazShare(url),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Rumble download error: $e');
    } finally {
      isDownloadLoading.value = false;
    }
  }

  /// Shares Odysee URL to VidBlaze for downloading.
  Future<void> goToOdyseeDownload() async {
    if (isDownloadLoading.value) return;

    if (episode.odyseeId.isEmpty) {
      AppSnackbar.error(
        'Download Unavailable',
        'Download link for this episode is not available yet.',
      );
      return;
    }

    try {
      isDownloadLoading.value = true;
      final url = 'https://odysee.com/${episode.odyseeId}';
      await _adService.showRewardedForDownload(
        onRewarded: () => _handleVidblazShare(url),
        onNotAvailable: () => _handleVidblazShare(url),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Odysee download error: $e');
    } finally {
      isDownloadLoading.value = false;
    }
  }

  static const _vidswiftChannel = MethodChannel(
    'com.dramahub.drama_hub/vidblaze',
  );

  Future<void> _handleVidblazShare(String url) async {
    try {
      final installed =
          await _vidswiftChannel.invokeMethod<bool>('isInstalled') ?? false;
      if (!installed) {
        Get.bottomSheet(
          const VidswiftInstallSheet(),
          isScrollControlled: true,
          ignoreSafeArea: false,
        );
        return;
      }
      final launched =
          await _vidswiftChannel.invokeMethod<bool>('shareToVidblaze', {
            'url': url,
          }) ??
          false;
      if (!launched) {
        Get.bottomSheet(
          const VidswiftInstallSheet(),
          isScrollControlled: true,
          ignoreSafeArea: false,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Vidblaze channel error: $e');
      Get.bottomSheet(
        const VidswiftInstallSheet(),
        isScrollControlled: true,
        ignoreSafeArea: false,
      );
    }
  }
}
