import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/utils/constants.dart';
import 'package:drama_hub/config/app_config_service.dart';

List<DramaModel> _parseDramas(String responseBody) {
  final List<dynamic> jsonList = jsonDecode(responseBody);
  return jsonList.map((e) => DramaModel.fromJson(e)).toList();
}

List<EpisodeModel> _parseEpisodes(String responseBody) {
  final List<dynamic> jsonList = jsonDecode(responseBody);
  return jsonList.map((json) => EpisodeModel.fromJson(json)).toList();
}

class DataService {
  static const String _baseUrl =
      'https://dramahub-data.waseyjamal000.workers.dev';
  static const String _localDramasFallback = 'assets/data/dramas.json';

  // ✅ 10 min TTL — Cloudflare caches for 5 min, app caches for 10 min
  // When data_version bumps, cache is cleared immediately anyway
  static const Duration _episodeCacheTTL = Duration(minutes: 10);

  // ── Dramas ──────────────────────────────────────────────────────────────

  Future<List<DramaModel>> loadDramas() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/dramas.json'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return compute(_parseDramas, response.body);
      } else {
        debugPrint('Failed to load remote dramas: ${response.statusCode}');
        return _loadLocalDramas();
      }
    } catch (e) {
      debugPrint('Error fetching dramas: $e');
      return _loadLocalDramas();
    }
  }

  Future<List<DramaModel>> _loadLocalDramas() async {
    try {
      final String jsonString = await rootBundle.loadString(
        _localDramasFallback,
      );
      return compute(_parseDramas, jsonString);
    } catch (e) {
      debugPrint('Error loading local dramas: $e');
      return [];
    }
  }

  // ── Episodes ─────────────────────────────────────────────────────────────

  Future<List<EpisodeModel>> loadEpisodes(String dramaId) async {
    // ✅ Always check data_version BEFORE serving cache
    // This fixes the bug where Episodes screen bypassed version check
    await _checkAndClearCacheIfVersionChanged();

    final cached = await _getCachedEpisodes(dramaId);
    if (cached != null) return cached;

    try {
      final String remoteUrl = '$_baseUrl/episodes/$dramaId.json';
      final response = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final episodes = await compute(_parseEpisodes, response.body);
        await _cacheEpisodes(dramaId, response.body);
        return episodes;
      } else {
        debugPrint(
          'Failed to load remote episodes for $dramaId: ${response.statusCode}',
        );
        return _loadLocalEpisodes(dramaId);
      }
    } catch (e) {
      debugPrint('Error loading remote episodes for $dramaId: $e');
      return _loadLocalEpisodes(dramaId);
    }
  }

  // ✅ Checks data_version from AppConfigService and clears all episode
  // caches if version changed — called before every episode cache read
  Future<void> _checkAndClearCacheIfVersionChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newVersion = AppConfigService.instance.config.dataVersion;
      final savedVersion = prefs.getInt(StorageKeys.dataVersion) ?? 0;

      if (newVersion != savedVersion && newVersion > 0) {
        debugPrint(
          'DataService: data_version $savedVersion → $newVersion — clearing episode caches',
        );
        final keys = prefs.getKeys().toList();
        for (final key in keys) {
          if (key.startsWith(StorageKeys.episodesCache) ||
              key.startsWith(StorageKeys.episodesCacheTime)) {
            await prefs.remove(key);
          }
        }
        await prefs.setInt(StorageKeys.dataVersion, newVersion);
      }
    } catch (e) {
      debugPrint('DataService: version check error — $e');
    }
  }

  Future<List<EpisodeModel>?> _getCachedEpisodes(String dramaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(
        '${StorageKeys.episodesCacheTime}$dramaId',
      );
      if (cacheTime == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (age > _episodeCacheTTL.inMilliseconds) return null;
      final cachedJson = prefs.getString(
        '${StorageKeys.episodesCache}$dramaId',
      );
      if (cachedJson == null) return null;
      return compute(_parseEpisodes, cachedJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheEpisodes(String dramaId, String jsonBody) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${StorageKeys.episodesCache}$dramaId', jsonBody);
      await prefs.setInt(
        '${StorageKeys.episodesCacheTime}$dramaId',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Episode cache write error: $e');
    }
  }

  Future<List<EpisodeModel>> _loadLocalEpisodes(String dramaId) async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/episodes/$dramaId.json',
      );
      return compute(_parseEpisodes, jsonString);
    } catch (e) {
      debugPrint('Error loading local episodes for $dramaId: $e');
      try {
        final String jsonString = await rootBundle.loadString(
          'assets/data/episodes.json',
        );
        final allEpisodes = await compute(_parseEpisodes, jsonString);
        return allEpisodes.where((ep) => ep.dramaId == dramaId).toList();
      } catch (e2) {
        debugPrint('Error loading legacy local episodes: $e2');
        return [];
      }
    }
  }
}
