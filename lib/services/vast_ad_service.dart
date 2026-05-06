import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:drama_hub/models/vast_ad_config_model.dart';
import 'package:drama_hub/services/ad_config_service.dart';

class VastAdResult {
  final bool success;
  final String mp4Url;
  final String network;

  VastAdResult({
    required this.success,
    required this.mp4Url,
    required this.network,
  });

  factory VastAdResult.empty() =>
      VastAdResult(success: false, mp4Url: '', network: '');
}

class VastAdService extends GetxService {
  static VastAdService get instance => Get.find<VastAdService>();

  int _sessionAdCount = 0;
  DateTime? _lastAdShownTime;
  DateTime _sessionStartTime = DateTime.now();

  VastAdConfig get _config => AdConfigService.instance.config.vast;

  /// Call this when app resumes to reset session if needed
  void checkSessionReset() {
    final diff = DateTime.now().difference(_sessionStartTime);
    if (diff.inHours >= 4) {
      _sessionAdCount = 0;
      _sessionStartTime = DateTime.now();
      debugPrint('VastAdService: session reset');
    }
  }

  /// Returns true if VAST ad can be shown right now
  bool canShowAd() {
    if (!_config.enabled) return false;
    if (_config.activeWaterfall.isEmpty) return false;

    checkSessionReset();

    // Check max per session
    if (_sessionAdCount >= _config.maxPerSession) {
      debugPrint('VastAdService: max per session reached');
      return false;
    }

    // Check gap between ads
    if (_lastAdShownTime != null) {
      final elapsed = DateTime.now().difference(_lastAdShownTime!);
      if (elapsed.inMinutes < _config.gapBetweenAdsMinutes) {
        debugPrint('VastAdService: gap not reached yet');
        return false;
      }
    }

    return true;
  }

  /// Tries each waterfall entry in priority order
  /// Returns first successful VastAdResult or empty on all fail
  Future<VastAdResult> fetchAd() async {
    final waterfall = _config.activeWaterfall;

    for (final entry in waterfall) {
      debugPrint('VastAdService: trying ${entry.network}');
      try {
        final result = await _fetchVastXml(entry);
        if (result.success) {
          debugPrint('VastAdService: got ad from ${entry.network}');
          return result;
        }
      } catch (e) {
        debugPrint('VastAdService: ${entry.network} failed — $e');
        continue;
      }
    }

    debugPrint('VastAdService: all networks failed');
    return VastAdResult.empty();
  }

  /// Fetches VAST XML and extracts MP4 url
  Future<VastAdResult> _fetchVastXml(VastWaterfallEntry entry) async {
    final response = await http
        .get(Uri.parse(entry.url))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      return VastAdResult.empty();
    }

    final xml = response.body;

    // Extract MP4 url from VAST XML
    final mp4Match = RegExp(
      r'<MediaFile[^>]*type="video/mp4"[^>]*>\s*<!\[CDATA\[\s*(https?://[^\]]+?\.mp4)\s*\]\]>\s*</MediaFile>',
      caseSensitive: false,
    ).firstMatch(xml);

    if (mp4Match == null) {
      debugPrint('VastAdService: no MP4 found in VAST from ${entry.network}');
      return VastAdResult.empty();
    }

    final mp4Url = mp4Match.group(1)?.trim() ?? '';
    if (mp4Url.isEmpty) return VastAdResult.empty();

    return VastAdResult(
      success: true,
      mp4Url: mp4Url,
      network: entry.network,
    );
  }

  /// Call this after ad is shown successfully
  void recordAdShown() {
    _sessionAdCount++;
    _lastAdShownTime = DateTime.now();
    debugPrint(
      'VastAdService: ad recorded — count: $_sessionAdCount',
    );
  }
}
