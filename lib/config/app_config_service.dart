import 'package:flutter/foundation.dart';
import 'package:drama_hub/config/app_config_model.dart';
import 'package:drama_hub/services/remote_config_service.dart';

/// Service responsible for loading and managing app configuration
class AppConfigService {
  /// Singleton instance
  static final AppConfigService _instance = AppConfigService._internal();

  /// Public accessor for singleton instance
  static AppConfigService get instance => _instance;

  /// Private constructor
  AppConfigService._internal();

  /// Current configuration (defaults to safe values)
  AppConfigModel _config = AppConfigModel.defaultConfig();

  /// Public getter for config
  AppConfigModel get config => _config;

  /// Loads configuration from Remote or Local Fallback
  ///
  /// Returns true if loaded successfully (even if fallback used), false otherwise.
  Future<bool> loadConfig() async {
    try {
      final RemoteConfigService remoteService = RemoteConfigService();
      final Map<String, dynamic> configMap = await remoteService
          .fetchAppConfig();

      _config = AppConfigModel.fromJson(configMap);
      return true;
    } catch (e) {
      debugPrint('Config load failed: $e');
      _config = AppConfigModel.defaultConfig();
      return false;
    }
  }

  /// ✅ NEW — Re-fetches config from GitHub and updates in memory.
  /// Called by HomeController every time dramas are refreshed.
  /// This makes admin changes to hero_slider_dramas reflect in user app
  /// without needing a full app restart.
  /// On failure: keeps current config — does NOT reset to defaults.
  Future<void> reloadConfig() async {
    try {
      final RemoteConfigService remoteService = RemoteConfigService();
      final Map<String, dynamic> configMap = await remoteService
          .fetchAppConfig();
      _config = AppConfigModel.fromJson(configMap);
      debugPrint(
        'AppConfigService: reloaded — heroIds: ${_config.heroSliderDramaIds}',
      );
    } catch (e) {
      debugPrint(
        'AppConfigService: reload failed, keeping current config — $e',
      );
    }
  }
}
