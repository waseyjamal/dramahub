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
  final String impressionUrl;

  VastAdResult({
    required this.success,
    required this.mp4Url,
    required this.network,
    this.impressionUrl = '',
  });

  factory VastAdResult.empty() =>
      VastAdResult(success: false, mp4Url: '', network: '', impressionUrl: '');
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
    return await _fetchWithRedirect(entry.url, entry.network, depth: 0);
  }

  Future<VastAdResult> _fetchWithRedirect(String url, String network,
      {int depth = 0}) async {
    if (depth > 3) {
      debugPrint('VastAdService: max wrapper depth reached');
      return VastAdResult.empty();
    }

    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      debugPrint('VastAdService: HTTP ${response.statusCode} from $url');
      return VastAdResult.empty();
    }

    final xml = response.body;

    // Check for VAST Wrapper tag (Redirect)
    final wrapperMatch = RegExp(
      r'<VASTAdTagURI[^>]*>\s*<!\[CDATA\[\s*(https?://\S+?)\s*\]\]>\s*</VASTAdTagURI>',
      caseSensitive: false,
    ).firstMatch(xml);

    if (wrapperMatch != null) {
      final wrapperUrl = wrapperMatch.group(1)?.trim() ?? '';
      if (wrapperUrl.isNotEmpty) {
        debugPrint('VastAdService: following wrapper → $wrapperUrl');
        return await _fetchWithRedirect(wrapperUrl, network, depth: depth + 1);
      }
    }

    // Extract MP4 url from VAST XML
    final cdataMatch = RegExp(
      r'<MediaFile[^>]*>\s*<!\[CDATA\[\s*(https?://\S+?)\s*\]\]>\s*</MediaFile>',
      caseSensitive: false,
    ).firstMatch(xml);

    final plainMatch = RegExp(
      r'<MediaFile[^>]*>\s*(https?://\S+?)\s*</MediaFile>',
      caseSensitive: false,
    ).firstMatch(xml);

    final mp4Url =
        cdataMatch?.group(1)?.trim() ?? plainMatch?.group(1)?.trim() ?? '';

    if (mp4Url.isEmpty) {
      debugPrint('VastAdService: no MP4 found in VAST from $network');
      return VastAdResult.empty();
    }

    // Extract Impression URL
    final impressionMatch = RegExp(
      r'<Impression[^>]*>\s*<!\[CDATA\[\s*(https?://\S+?)\s*\]\]>\s*</Impression>',
      caseSensitive: false,
    ).firstMatch(xml);
    final impressionUrl = impressionMatch?.group(1)?.trim() ?? '';

    return VastAdResult(
      success: true,
      mp4Url: mp4Url,
      network: network,
      impressionUrl: impressionUrl,
    );
  }

  /// Silently fires a GET request to the impression URL
  Future<void> fireImpression(String impressionUrl) async {
    if (impressionUrl.isEmpty) return;
    http.get(Uri.parse(impressionUrl)).catchError((_) {
      return http.Response('', 404);
    });
    debugPrint('VastAdService: impression fired for $impressionUrl');
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
