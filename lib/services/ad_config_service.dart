import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ad_config_model.dart';

class AdConfigService {
  static const String _configUrl =
      'https://raw.githubusercontent.com/waseyjamal/dramahub-data/main/ad_config.json';

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
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _config = AdConfigModel.fromJson(json);
        debugPrint('✅ AdConfig loaded from remote');
      } else {
        debugPrint(
          '⚠️ AdConfig fetch failed: ${response.statusCode}, using defaults',
        );
      }
    } catch (e) {
      debugPrint('⚠️ AdConfig fetch error: $e, using defaults');
      // Falls back to AdConfigModel.defaults() — app works normally
    } finally {
      _isInitialized = true; // ✅ B-4 — always mark ready, even on failure
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
}
