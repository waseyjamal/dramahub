import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoService {
  static const _channel = MethodChannel('com.dramahub.drama_hub/security');

  bool _isSecureModeEnabled = false;
  bool get isSecureModeEnabled => _isSecureModeEnabled;

  Future<void> enableSecureMode() async {
    try {
      await _channel.invokeMethod('enableSecureMode');
      _isSecureModeEnabled = true;
      if (kDebugMode) { debugPrint('VideoService: secure mode enabled'); }
    } catch (e) {
      if (kDebugMode) { debugPrint('VideoService: enableSecureMode failed — $e'); }
    }
  }

  Future<void> disableSecureMode() async {
    try {
      await _channel.invokeMethod('disableSecureMode');
      _isSecureModeEnabled = false;
      if (kDebugMode) { debugPrint('VideoService: secure mode disabled'); }
    } catch (e) {
      if (kDebugMode) { debugPrint('VideoService: disableSecureMode failed — $e'); }
    }
  }
}
