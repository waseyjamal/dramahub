import 'dart:convert';
import 'package:flutter/foundation.dart'; // ✅ add this import
import 'package:http/http.dart' as http;

class RemoteConfigService {
  static const String _configUrl =
      'https://dramahub-data.waseyjamal000.workers.dev/app_config.json';

  static const Map<String, dynamic> _defaultConfig = {
    "min_version": 1,
    "latest_version": 1,
    "force_update": false,
    "maintenance_mode": false,
  };

  // GitHub raw — independent of Cloudflare, used as fallback
  static const String _githubFallbackUrl =
      'https://raw.githubusercontent.com/waseyjamal/dramahub-data/main/app_config.json';

  Future<Map<String, dynamic>> fetchAppConfig() async {
    // Try primary (Cloudflare Worker) first
    final primary = await _fetchFrom(_configUrl);
    if (primary != null) return primary;

    if (kDebugMode) { debugPrint('⚠️ Primary config fetch failed — trying GitHub fallback'); }

    // Try GitHub raw directly (completely independent of Cloudflare)
    final fallback = await _fetchFrom(_githubFallbackUrl);
    if (fallback != null) return fallback;

    if (kDebugMode) { debugPrint('⚠️ Both config sources failed — using defaults'); }
    return _defaultConfig;
  }

  Future<Map<String, dynamic>?> _fetchFrom(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (kDebugMode) { debugPrint('Config fetch non-200 from $url: ${response.statusCode}'); }
      return null;
    } catch (e) {
      if (kDebugMode) { debugPrint('Config fetch error from $url: $e'); }
      return null;
    }
  }
}
