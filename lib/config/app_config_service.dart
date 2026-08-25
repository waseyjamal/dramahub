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

  // Throttle — prevents hammering config on every loadDramas()
  // Resume bypasses this — always fetches fresh on app resume
  DateTime? _lastReloadTime;
  static const Duration _reloadThrottle = Duration(minutes: 5);

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
      if (kDebugMode) { debugPrint('Config load failed: $e'); }
      _config = AppConfigModel.defaultConfig();
      return false;
    }
  }

  /// Re-fetches config. Called by HomeController on loadDramas().
  /// Throttled to 5 min — EXCEPT when forceResume=true (app came from background).
  /// On failure: keeps current config, does NOT reset to defaults.
  Future<void> reloadConfig({bool forceResume = false}) async {
    final now = DateTime.now();
    if (!forceResume &&
        _lastReloadTime != null &&
        now.difference(_lastReloadTime!) < _reloadThrottle) {
      if (kDebugMode) {
        debugPrint(
          'AppConfigService: throttled — skipping reload '
          '(${now.difference(_lastReloadTime!).inSeconds}s since last fetch)',
        );
      }
      return;
    }
    try {
      final RemoteConfigService remoteService = RemoteConfigService();
      final Map<String, dynamic> configMap =
          await remoteService.fetchAppConfig();
      _config = AppConfigModel.fromJson(configMap);
      _lastReloadTime = now;
      if (kDebugMode) {
        debugPrint(
          'AppConfigService: reloaded — heroIds: ${_config.heroSliderDramaIds}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'AppConfigService: reload failed, keeping current config — $e',
        );
      }
    }
  }
}
