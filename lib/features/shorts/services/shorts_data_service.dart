import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/models/shorts_config_model.dart';

/// Loads Shorts JSON from the CDN:
///   $cdnBase/shorts/config.json
///   $cdnBase/shorts/feed.json
///   $cdnBase/shorts/series/{id}.json
///
/// Feed and series responses are cached for [cacheTtl]. The cache is cleared
/// when `data_version` in config.json changes. When the network fails, the
/// last cached copy is served even if expired, so the feature works offline
/// as far as possible.
class ShortsDataService {
  ShortsDataService({
    http.Client? client,
    String Function()? baseUrl,
    this.cacheTtl = const Duration(minutes: 5),
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? (() => AppConfigService.instance.config.cdnBase);

  final http.Client _client;
  final String Function() _baseUrl;
  final Duration cacheTtl;
  final Duration timeout;

  static const String _prefix = 'shorts_cache_';
  static const String _timePrefix = 'shorts_cache_time_';
  static const String _configKey = 'shorts_config_json';
  static const String _versionKey = 'shorts_data_version';

  // ── Config ───────────────────────────────────────────────────────────────

  /// Last config saved on device — used instantly at startup so the
  /// Shorts tab doesn't pop in and out while the network request runs.
  Future<ShortsConfig> cachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_configKey);
      if (raw == null) return ShortsConfig.disabled;
      return _parseConfig(raw) ?? ShortsConfig.disabled;
    } catch (_) {
      return ShortsConfig.disabled;
    }
  }

  /// Fetches the remote config. Returns null on network failure so the
  /// caller can keep the cached config instead of hiding the feature.
  /// A 404 means the admin hasn't published the feature: returns disabled.
  Future<ShortsConfig?> fetchConfig() async {
    try {
      final res = await _get('shorts/config.json');
      final prefs = await SharedPreferences.getInstance();
      if (res.statusCode == 404) {
        await prefs.remove(_configKey);
        return ShortsConfig.disabled;
      }
      if (res.statusCode != 200) return null;
      final config = _parseConfig(res.body);
      if (config == null) return null;
      await prefs.setString(_configKey, res.body);
      await _bustCacheIfVersionChanged(prefs, config.dataVersion);
      return config;
    } catch (e) {
      if (kDebugMode) debugPrint('Shorts: config fetch failed — $e');
      return null;
    }
  }

  // ── Feed / series ────────────────────────────────────────────────────────

  Future<List<ShortFeedEntry>> loadFeed({bool forceRefresh = false}) async {
    final body = await _loadJson('shorts/feed.json', forceRefresh);
    if (body == null) throw const ShortsLoadException();
    final decoded = jsonDecode(body);
    final list = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> && decoded['items'] is List
              ? decoded['items'] as List
              : const []);
    return list
        .map(ShortFeedEntry.tryParse)
        .whereType<ShortFeedEntry>()
        .toList();
  }

  Future<ShortSeries> loadSeries(
    String seriesId, {
    bool forceRefresh = false,
  }) async {
    final body = await _loadJson(
      'shorts/series/${Uri.encodeComponent(seriesId)}.json',
      forceRefresh,
    );
    if (body == null) throw const ShortsLoadException();
    final series = ShortSeries.tryParse(jsonDecode(body));
    if (series == null || series.episodes.isEmpty) {
      throw const ShortsLoadException();
    }
    return series;
  }

  // ── Internals ────────────────────────────────────────────────────────────

  Future<http.Response> _get(String path) =>
      _client.get(Uri.parse('${_baseUrl()}/$path')).timeout(timeout);

  /// Fresh cache → network → stale cache → null.
  Future<String?> _loadJson(String path, bool forceRefresh) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    final cached = prefs?.getString('$_prefix$path');
    final cachedAt = prefs?.getInt('$_timePrefix$path') ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    if (!forceRefresh && cached != null && age < cacheTtl.inMilliseconds) {
      return cached;
    }

    try {
      final res = await _get(path);
      if (res.statusCode == 200) {
        jsonDecode(res.body); // validate before caching
        await prefs?.setString('$_prefix$path', res.body);
        await prefs?.setInt(
          '$_timePrefix$path',
          DateTime.now().millisecondsSinceEpoch,
        );
        return res.body;
      }
      if (kDebugMode) debugPrint('Shorts: $path → ${res.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('Shorts: $path failed — $e');
    }
    return cached;
  }

  Future<void> _bustCacheIfVersionChanged(
    SharedPreferences prefs,
    int version,
  ) async {
    if (version <= 0 || prefs.getInt(_versionKey) == version) return;
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
    await prefs.setInt(_versionKey, version);
  }

  ShortsConfig? _parseConfig(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic>
          ? ShortsConfig.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }
}

class ShortsLoadException implements Exception {
  const ShortsLoadException();
}
