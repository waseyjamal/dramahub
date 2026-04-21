import 'dart:convert';
import 'package:flutter/foundation.dart'; // ✅ add this import
import 'package:http/http.dart' as http;

class RemoteConfigService {
  static const String _configUrl =
      'https://raw.githubusercontent.com/waseyjamal/dramahub-data/main/app_config.json';

  static const Map<String, dynamic> _defaultConfig = {
    "min_version": 1,
    "latest_version": 1,
    "force_update": false,
    "maintenance_mode": false,
  };

  Future<Map<String, dynamic>> fetchAppConfig() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$_configUrl?t=$timestamp';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint(
          'Failed to load app config: ${response.statusCode}',
        ); // ✅ 8.5
        return _defaultConfig;
      }
    } catch (e) {
      debugPrint('Error fetching app config: $e'); // ✅ 8.5
      return _defaultConfig;
    }
  }
}
