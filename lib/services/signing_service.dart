import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:drama_hub/config/app_config_service.dart';

/// SigningService — fetches signed video URLs from Deno Deploy signing API.
///
/// Flow:
/// 1. Check use_signed_urls flag from config — if false, return raw URL
/// 2. Call primary signing API
/// 3. If primary fails → call fallback signing API
/// 4. If both fail → return raw URL (emergency fallback, app never breaks)
///
/// Used by: video_screen.dart (_startHlsPlayer) and download_service.dart
class SigningService {
  SigningService._();
  static final SigningService instance = SigningService._();

  static const Duration _timeout = Duration(seconds: 8);

  /// Get signed stream URL (5 min expiry)
  Future<String> getStreamUrl({
    required String dramaId,
    required int episodeNumber,
    required String rawUrl,
  }) async {
    return _getSignedUrl(
      dramaId: dramaId,
      episodeNumber: episodeNumber,
      rawUrl: rawUrl,
      type: 'stream',
    );
  }

  /// Get signed download URL (6 hour expiry)
  Future<String> getDownloadUrl({
    required String dramaId,
    required int episodeNumber,
    required String rawUrl,
  }) async {
    return _getSignedUrl(
      dramaId: dramaId,
      episodeNumber: episodeNumber,
      rawUrl: rawUrl,
      type: 'download',
    );
  }

  Future<String> _getSignedUrl({
    required String dramaId,
    required int episodeNumber,
    required String rawUrl,
    required String type,
  }) async {
    final config = AppConfigService.instance.config;

    // If signing is disabled by admin — use raw URL immediately
    if (!config.useSignedUrls) {
      if (kDebugMode)
        debugPrint('SigningService: signing disabled — using raw URL');
      return rawUrl;
    }

    // If no signing API configured — use raw URL
    if (config.signingApi.isEmpty) {
      if (kDebugMode)
        debugPrint('SigningService: no signing API configured — using raw URL');
      return rawUrl;
    }

    // Try primary signing API
    final primaryResult = await _callSigningApi(
      apiUrl: config.signingApi,
      dramaId: dramaId,
      episodeNumber: episodeNumber,
      type: type,
    );
    if (primaryResult != null) {
      if (kDebugMode) debugPrint('SigningService: signed via primary ✅');
      return primaryResult;
    }

    if (kDebugMode)
      debugPrint('SigningService: primary failed — trying fallback');

    // Try fallback signing API
    if (config.signingApiFallback.isNotEmpty) {
      final fallbackResult = await _callSigningApi(
        apiUrl: config.signingApiFallback,
        dramaId: dramaId,
        episodeNumber: episodeNumber,
        type: type,
      );
      if (fallbackResult != null) {
        if (kDebugMode) debugPrint('SigningService: signed via fallback ✅');
        return fallbackResult;
      }
    }

    // Both failed — use raw URL so app never breaks
    if (kDebugMode)
      debugPrint(
        'SigningService: both APIs failed — using raw URL as emergency fallback',
      );
    return rawUrl;
  }

  Future<String?> _callSigningApi({
    required String apiUrl,
    required String dramaId,
    required int episodeNumber,
    required String type,
  }) async {
    try {
      final uri = Uri.parse(apiUrl).replace(
        queryParameters: {
          'dramaId': dramaId,
          'ep': episodeNumber.toString(),
          'type': type,
        },
      );

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('SigningService: API returned ${response.statusCode}');
        }
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['url'] as String?;

      if (url == null || url.isEmpty) {
        if (kDebugMode) debugPrint('SigningService: empty URL in response');
        return null;
      }

      return url;
    } catch (e) {
      if (kDebugMode) debugPrint('SigningService: error — $e');
      return null;
    }
  }
}
