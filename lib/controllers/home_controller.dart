import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/services/data_service.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/utils/constants.dart';
import 'package:drama_hub/config/app_config_service.dart';
import 'dart:async';
import 'package:drama_hub/controllers/episodes_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeController extends GetxController {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final DataService _dataService = Get.find<DataService>();

  static const int _pageSize = 10;
  // ✅ Drama cache TTL reduced to 10 minutes — matches episode TTL
  static const Duration _dramaCacheTTL = Duration(minutes: 10);

  final RxInt _currentPage = 1.obs;
  final RxBool hasMoreDramas = false.obs;

  final RxList<DramaModel> allDramas = <DramaModel>[].obs;
  final RxList<DramaModel> filteredDramas = <DramaModel>[].obs;
  final RxList<DramaModel> heroSliderDramas = <DramaModel>[].obs;

  final RxList<Map<String, dynamic>> latestEpisodes =
      <Map<String, dynamic>>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool hasInternet = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isOfflineCached = false.obs;

  final RxString lastDramaId = ''.obs;
  final RxString lastDramaTitle = ''.obs;
  final RxString lastDramaBanner = ''.obs;
  final RxInt lastEpisodeNumber = 0.obs;

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    loadLastWatched();
    loadDramas();
  }

  Future<void> _cacheDramas(List<DramaModel> dramas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = dramas.map((d) => jsonEncode(d.toJson())).toList();
      await prefs.setStringList(StorageKeys.cachedDramas, jsonList);
      await prefs.setInt(
        StorageKeys.cachedDramasTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) { debugPrint('Cache save error: $e'); }
    }
  }

  Future<List<DramaModel>> _loadCachedDramas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(StorageKeys.cachedDramas) ?? [];
      if (jsonList.isEmpty) return [];
      return jsonList.map((e) => DramaModel.fromJson(jsonDecode(e))).toList();
    } catch (e) {
      if (kDebugMode) { debugPrint('Cache load error: $e'); }
      return [];
    }
  }

  Future<void> loadDramas({bool forceRefresh = false}) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        hasInternet.value = false;
        final cached = await _loadCachedDramas();
        if (cached.isNotEmpty) {
          allDramas.assignAll(cached);
          filteredDramas.assignAll(cached);
          isOfflineCached.value = true;
          _resolveHeroSlider(cached);
        }
        isLoading.value = false;
        return;
      }

      hasInternet.value = true;
      isOfflineCached.value = false;

      final prefs = await SharedPreferences.getInstance();

      // ✅ FIXED: No more 15-min throttle — reload config on every loadDramas()
      // app_config.json is tiny (~500 bytes) served from Cloudflare edge
      // This ensures data_version is always current before cache check
      await AppConfigService.instance.reloadConfig();
      _checkAndShowUpdateDialog();

      // ✅ Version check — clears all caches if data_version bumped
      final newVersion = AppConfigService.instance.config.dataVersion;
      final savedVersion = prefs.getInt(StorageKeys.dataVersion) ?? 0;
      if (newVersion != savedVersion) {
        if (kDebugMode) {
          debugPrint(
            'data_version changed $savedVersion → $newVersion — clearing all caches',
          );
        }
        await prefs.remove(StorageKeys.cachedDramas);
        await prefs.remove(StorageKeys.cachedDramasTime);
        final keys = prefs.getKeys().toList();
        for (final key in keys) {
          if (key.startsWith(StorageKeys.episodesCache) ||
              key.startsWith(StorageKeys.episodesCacheTime)) {
            await prefs.remove(key);
          }
        }
        await prefs.setInt(StorageKeys.dataVersion, newVersion);
      }

      // ✅ Check drama cache AFTER version check — 10 min TTL
      final cacheTime = prefs.getInt(StorageKeys.cachedDramasTime) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
      final isCacheFresh =
          !forceRefresh && cacheAge < _dramaCacheTTL.inMilliseconds;

      if (isCacheFresh) {
        final cached = await _loadCachedDramas();
        if (cached.isNotEmpty) {
          if (kDebugMode) { debugPrint('Drama cache hit — ${cached.length} dramas'); }
          allDramas.assignAll(cached);
          _currentPage.value = 1;
          hasMoreDramas.value = cached.length > _pageSize;
          filteredDramas.assignAll(cached.take(_pageSize).toList());
          _resolveHeroSlider(cached);
          // ✅ Background refresh latest episodes even on cache hit
          _loadLatestEpisodes(cached);
          isLoading.value = false;
          return;
        }
      }

      final loadedDramas = await _dataService.loadDramas();
      final activeDramas = loadedDramas.where((d) => d.isActive).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      allDramas.assignAll(activeDramas);
      _currentPage.value = 1;
      hasMoreDramas.value = activeDramas.length > _pageSize;
      filteredDramas.assignAll(activeDramas.take(_pageSize).toList());
      _analytics.logAppOpen();
      _preloadImages(activeDramas);
      await _cacheDramas(activeDramas);
      _resolveHeroSlider(activeDramas);
      _loadLatestEpisodes(activeDramas);
    } catch (e) {
      if (kDebugMode) { debugPrint('Error loading dramas: $e'); }
      hasError.value = true;
      errorMessage.value = 'Something went wrong. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  void _resolveHeroSlider(List<DramaModel> dramas) {
    try {
      final config = AppConfigService.instance.config;
      final heroIds = config.heroSliderDramaIds;

      if (heroIds.isNotEmpty) {
        final List<DramaModel> ordered = [];
        for (final id in heroIds) {
          final drama = dramas.firstWhereOrNull((d) => d.id == id);
          if (drama != null) ordered.add(drama);
        }
        if (ordered.isNotEmpty) {
          heroSliderDramas.assignAll(ordered);
          return;
        }
      }

      heroSliderDramas.assignAll(dramas.take(3).toList());
    } catch (e) {
      if (kDebugMode) { debugPrint('Hero slider resolve error: $e'); }
      heroSliderDramas.assignAll(dramas.take(3).toList());
    }
  }

  Future<void> _loadLatestEpisodes(List<DramaModel> dramas) async {
    try {
      final List<Map<String, dynamic>> results = [];

      const int maxConcurrent = 5;
      int active = 0;
      int index = 0;

      Future<void> processNext() async {
        while (index < dramas.length) {
          if (active >= maxConcurrent) {
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          final drama = dramas[index++];
          active++;

          unawaited(
            (() async {
              try {
                final episodes = await _dataService.loadEpisodes(drama.id);
                if (episodes.isNotEmpty) {
                  final released = episodes.where((e) => e.isReleased).toList()
                    ..sort(
                      (a, b) => b.episodeNumber.compareTo(a.episodeNumber),
                    );
                  if (released.isNotEmpty) {
                    results.add({'episode': released.first, 'drama': drama});
                  }
                }
              } catch (e) {
                if (kDebugMode) { debugPrint('Episode load failed for ${drama.id}: $e'); }
              } finally {
                active--;
              }
            })(),
          );
        }
      }

      await processNext();
      while (active > 0) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      results.sort((a, b) {
        final epA = a['episode'] as EpisodeModel;
        final epB = b['episode'] as EpisodeModel;
        return epB.releaseDate.compareTo(epA.releaseDate);
      });

      latestEpisodes.assignAll(results.take(10).toList());
    } catch (e) {
      if (kDebugMode) { debugPrint('Error loading latest episodes: $e'); }
    }
  }

  void loadMoreDramas() {
    final nextPage = _currentPage.value + 1;
    final end = nextPage * _pageSize;
    if (end >= allDramas.length) {
      filteredDramas.assignAll(allDramas);
      hasMoreDramas.value = false;
    } else {
      filteredDramas.assignAll(allDramas.take(end).toList());
      hasMoreDramas.value = true;
    }
    _currentPage.value = nextPage;
  }

  Future<void> loadLastWatched() async {
    final prefs = await SharedPreferences.getInstance();
    lastDramaId.value = prefs.getString(StorageKeys.lastDramaId) ?? '';
    lastDramaTitle.value = prefs.getString(StorageKeys.lastDramaTitle) ?? '';
    lastDramaBanner.value = prefs.getString(StorageKeys.lastDramaBanner) ?? '';
    lastEpisodeNumber.value = prefs.getInt(StorageKeys.lastEpisodeNumber) ?? 0;
  }

  void goToEpisodes(DramaModel drama) {
    _analytics.logEvent(
      name: 'drama_opened',
      parameters: {'drama_id': drama.id, 'drama_title': drama.title},
    );
    Get.toNamed(
      AppRoutes.episodes,
      arguments: drama,
    )?.then((_) => loadLastWatched());
  }

  void goToEpisodesSkipAd(DramaModel drama) {
    Get.delete<EpisodesController>(force: true);
    _analytics.logEvent(
      name: 'drama_opened',
      parameters: {'drama_id': drama.id, 'drama_title': drama.title},
    );
    Get.toNamed(
      AppRoutes.episodes,
      arguments: {'drama': drama, 'skipAd': true},
    )?.then((_) => loadLastWatched());
  }

  void goToLastWatchedEpisode() {
    if (lastDramaId.value.isEmpty || lastEpisodeNumber.value == 0) return;

    final drama = allDramas.firstWhereOrNull((d) => d.id == lastDramaId.value);
    if (drama == null) return;

    // 🚀 INSTANT NAVIGATION (Sliding Transition)
    // Matches the "Home to Episodes" feel.
    Get.toNamed(
      AppRoutes.episodes,
      arguments: {'drama': drama, 'autoPlayEpisode': lastEpisodeNumber.value},
    )?.then((_) => loadLastWatched());
  }

  void filterDramas(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        _currentPage.value = 1;
        hasMoreDramas.value = allDramas.length > _pageSize;
        filteredDramas.assignAll(allDramas.take(_pageSize).toList());
      } else {
        hasMoreDramas.value = false;
        filteredDramas.assignAll(
          allDramas
              .where((d) => d.title.toLowerCase().contains(query.toLowerCase()))
              .toList(),
        );
        _analytics.logSearch(searchTerm: query);
      }
    });
  }

  void _preloadImages(List<DramaModel> dramas) {
    final context = Get.context;
    if (context == null) return;
    final preloadList = dramas.take(4).toList();
    for (final drama in preloadList) {
      if (drama.posterImage.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(drama.posterImage), context);
      }
    }
  }

  // ✅ Force update safety net — runs after reloadConfig() on home load
  // Catches users whose startup check timed out on slow connections
  static const int _currentAppVersion = 7;
  bool _updateDialogShown = false;

  void _checkAndShowUpdateDialog() {
    if (_updateDialogShown) return;
    final config = AppConfigService.instance.config;
    if (config.latestVersion <= _currentAppVersion) return;
    if (!config.forceUpdate) return;
    _updateDialogShown = true;
    Get.dialog(
      _buildUpdateDialog(force: true),
      barrierDismissible: false,
    );
  }

  Widget _buildUpdateDialog({required bool force}) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              force ? Icons.system_update_rounded : Icons.new_releases_rounded,
              color: force ? Colors.redAccent : Colors.amber,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              force ? 'Update Required' : 'Update Available',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              force
                  ? 'A new version of Drama Hub is available. Please update to continue.'
                  : 'A new version of Drama Hub is available with new features and improvements.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!force)
              TextButton(
                onPressed: () => Get.back(),
                child: const Text(
                  'Later',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!AppUrls.isSafeUrl(AppUrls.playStore)) return;
                  await launchUrl(
                    Uri.parse(AppUrls.playStore),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text(
                  'Update on Play Store',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }
}
