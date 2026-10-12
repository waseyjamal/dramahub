import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/config/app_config_model.dart';
import 'package:drama_hub/utils/constants.dart';

/// Decides whether this build is blocked by a server-side force update.
///
/// The required build is persisted, so once a device has seen
/// force_update=true it stays blocked on offline launches and failed
/// config fetches. Only a successful server config with force_update=false
/// (or a lower latestVersion) lifts the block — installing the new build
/// lifts it naturally because currentBuildVersion goes up.
class ForceUpdateService {
  static final ForceUpdateService instance = ForceUpdateService._();
  ForceUpdateService._();

  /// UI listens to this — true shows the full-screen update blocker.
  final RxBool isBlocked = false.obs;

  /// Call once before runApp — restores a block saved on a previous launch.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final required = prefs.getInt(StorageKeys.forcedMinBuild) ?? 0;
      _setBlocked(required > Constants.currentBuildVersion);
    } catch (e) {
      if (kDebugMode) debugPrint('ForceUpdate init failed: $e');
    }
  }

  /// Called by AppConfigService after every config load.
  /// [fromServer] false means built-in defaults — never lift a block on those.
  Future<void> onConfig(AppConfigModel config, {required bool fromServer}) async {
    final forced = config.forceUpdate &&
        config.latestVersion > Constants.currentBuildVersion;

    if (forced) {
      _setBlocked(true);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(StorageKeys.forcedMinBuild, config.latestVersion);
      } catch (_) {}
      return;
    }

    if (!fromServer) return;

    _setBlocked(false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.forcedMinBuild);
    } catch (_) {}
  }

  void _setBlocked(bool value) {
    if (isBlocked.value == value) return;
    isBlocked.value = value;
    if (value) {
      // Close video/dialogs/sub-screens so nothing keeps playing under the blocker.
      try {
        if (Get.key.currentState != null) Get.until((route) => route.isFirst);
      } catch (_) {}
    }
  }
}
