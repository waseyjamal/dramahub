import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ad_config_model.dart';

class AdConfigService {
  static const String _configUrl =
      'https://dramahub-data.pages.dev/ad_config.json';
  static const String _cacheKey = 'ad_config_cache';

  static AdConfigService? _instance;
  static AdConfigService get instance => _instance ??= AdConfigService._();
  AdConfigService._();

  AdConfigModel _config = AdConfigModel.defaults();
  AdConfigModel get config => _config;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Call this once at app startup
  Future<void> initialize() async {
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _config = AdConfigModel.fromJson(json);
        // ✅ Cache last good config so next fetch failure uses real config
        await _saveCache(response.body);
        if (kDebugMode) debugPrint('✅ AdConfig loaded from remote');
      } else {
        if (kDebugMode) {
          debugPrint(
            '⚠️ AdConfig fetch failed: ${response.statusCode} — trying cache',
          );
        }
        await _loadFromCache();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ AdConfig fetch error: $e — trying cache');
      // ✅ On any failure, load last known good config instead of defaults
      await _loadFromCache();
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> _saveCache(String rawJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, rawJson);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ AdConfig cache save error: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        _config = AdConfigModel.fromJson(json);
        if (kDebugMode) debugPrint('✅ AdConfig loaded from cache');
      } else {
        // No cache yet — first install, use defaults
        if (kDebugMode) debugPrint('⚠️ No AdConfig cache — using defaults');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ AdConfig cache load error: $e');
    }
  }

  /// Refresh config (call when app resumes from background)
  Future<void> refresh() => initialize();

  /// Quick helpers
  bool get adsEnabled => _config.adsEnabled;
  bool canShowInterstitialOn(String screen) =>
      _config.adsEnabled && _config.interstitial.isEnabledForScreen(screen);
  bool canShowRewardedOn(String screen) =>
      _config.adsEnabled && _config.rewarded.isEnabledForScreen(screen);
  bool get appOpenEnabled => _config.adsEnabled && _config.appOpen.enabled;
  OfflineAdConfig get offlineAds => _config.offlineAds;
}
