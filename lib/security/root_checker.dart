import 'dart:io';

/// Lightweight root detection for Android devices
class RootChecker {
  /// Common paths where root binaries are found
  static const List<String> _rootPaths = [
    '/system/app/Superuser.apk',
    '/system/xbin/su',
    '/system/bin/su',
    '/su/bin/su',
    '/sbin/su',
    '/system/sd/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
  ];

  /// Checks if the device appears to be rooted
  ///
  /// Returns true if any common root paths are found.
  /// This is a lightweight check and may have false positives/negatives.
  static bool isDeviceRooted() {
    // Only check on Android
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      for (final path in _rootPaths) {
        if (File(path).existsSync()) {
          return true;
        }
      }
      return false;
    } catch (e) {
      // If check fails, assume not rooted
      return false;
    }
  }
}
