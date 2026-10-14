import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/services/signing_service.dart';

/// Creates an initialized [VideoPlayerController] for a Shorts page.
/// Tries HLS first, then falls back to MP4.
class ShortsPlayerFactory {
  ShortsPlayerFactory._();

  static const Duration _initTimeout = Duration(seconds: 20);

  static Future<VideoPlayerController> create(ShortItem item) async {
    final ep = item.episode;
    final sources = <(String, bool)>[
      if (ep.hlsUrl.isNotEmpty) (ep.hlsUrl, true),
      if (ep.mp4Url.isNotEmpty) (ep.mp4Url, false),
    ];
    Object error = StateError('No video source for ${item.key}');

    for (var i = 0; i < sources.length; i++) {
      final (raw, isHls) = sources[i];
      final url = i == 0 ? await _resolve(item, raw) : raw;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        formatHint: isHls ? VideoFormat.hls : null,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      try {
        await controller.initialize().timeout(_initTimeout);
        await controller.setLooping(false);
        return controller;
      } catch (e) {
        error = e;
        if (kDebugMode) debugPrint('Shorts: source failed ($url) — $e');
        await controller.dispose();
      }
    }
    throw error;
  }

  /// Signs the primary source whenever the global app config enables
  /// signing (same switch as normal episodes). SigningService checks the
  /// flag itself and falls back to the raw URL on any failure.
  static Future<String> _resolve(ShortItem item, String rawUrl) async {
    try {
      return await SigningService.instance.getStreamUrl(
        dramaId: 'shorts_${item.series.id}',
        episodeNumber: item.episode.number,
        rawUrl: rawUrl,
      );
    } catch (_) {
      return rawUrl;
    }
  }
}
