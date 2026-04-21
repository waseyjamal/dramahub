import 'dart:convert';
import 'package:drama_hub/services/ad_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
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

class HomeController extends GetxController {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final DataService _dataService = Get.find<DataService>();

  static const int _pageSize = 10;
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

  DateTime? _lastConfigReload;

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
      debugPrint('Cache save error: $e');
    }
  }

  Future<List<DramaModel>> _loadCachedDramas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(StorageKeys.cachedDramas) ?? [];
      if (jsonList.isEmpty) return [];
      return jsonList.map((e) => DramaModel.fromJson(jsonDecode(e))).toList();
    } catch (e) {
      debugPrint('Cache load error: $e');
      return [];
    }
  }

  Future<void> loadDramas({bool forceRefresh = false}) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
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

      // ✅ 5.2 — Config reload throttled to 30 min
      // MUST run BEFORE cache check — version change invalidates cache
      final now = DateTime.now();
      if (_lastConfigReload == null ||
          now.difference(_lastConfigReload!) > const Duration(minutes: 15)) {
        await AppConfigService.instance.reloadConfig();
        _lastConfigReload = now;

        // ✅ version system — if data_version changed, clear all caches
        final newVersion = AppConfigService.instance.config.dataVersion;
        final savedVersion = prefs.getInt(StorageKeys.dataVersion) ?? 0;
        if (newVersion != savedVersion) {
          debugPrint(
            'data_version changed $savedVersion → $newVersion — clearing caches',
          );
          await prefs.remove(StorageKeys.cachedDramas);
          await prefs.remove(StorageKeys.cachedDramasTime);
          final keys = prefs.getKeys();
          for (final key in keys) {
            if (key.startsWith(StorageKeys.episodesCache) ||
                key.startsWith(StorageKeys.episodesCacheTime)) {
              await prefs.remove(key);
            }
          }
          await prefs.setInt(StorageKeys.dataVersion, newVersion);
        }
      }

      // ✅ 6.3 — Check drama cache AFTER version check
      // Cache may have been cleared above if version changed
      final cacheTime = prefs.getInt(StorageKeys.cachedDramasTime) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
      final isCacheFresh =
          !forceRefresh && cacheAge < const Duration(hours: 12).inMilliseconds;

      if (isCacheFresh) {
        final cached = await _loadCachedDramas();
        if (cached.isNotEmpty) {
          debugPrint('Drama cache hit — ${cached.length} dramas');
          allDramas.assignAll(cached);
          _currentPage.value = 1;
          hasMoreDramas.value = cached.length > _pageSize;
          filteredDramas.assignAll(cached.take(_pageSize).toList());
          _resolveHeroSlider(cached);
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
      debugPrint('Error loading dramas: $e');
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
      debugPrint('Hero slider resolve error: $e');
      heroSliderDramas.assignAll(dramas.take(3).toList());
    }
  }

  Future<void> _loadLatestEpisodes(List<DramaModel> dramas) async {
    try {
      final List<Map<String, dynamic>> results = [];

      // ✅ 6.4 — Semaphore: max 5 parallel requests at once
      // Previously: all 20+ fired simultaneously → GitHub rate limit hit
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

          // ✅ 6.1 — Each request fully isolated — one failure never affects others
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
                // ✅ 6.1 — Isolated: this drama fails silently, others continue
                debugPrint('Episode load failed for ${drama.id}: $e');
              } finally {
                active--;
              }
            })(),
          );
        }
      }

      await processNext();
      // Wait for all active requests to finish
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
      debugPrint('Error loading latest episodes: $e');
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
    _analytics.logEvent(
      name: 'drama_opened',
      parameters: {'drama_id': drama.id, 'drama_title': drama.title},
    );
    Get.toNamed(
      AppRoutes.episodes,
      arguments: {'drama': drama, 'skipAd': true},
    )?.then((_) => loadLastWatched());
  }

  void filterDramas(String query) {
    // ✅ 5.9 — 300ms debounce: cancel previous timer, only filter after pause
    // Prevents rebuilding grid on every single keystroke
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

    // ✅ 5.3 — Reduced from 8 dramas × 2 images = 16 requests
    // to 4 dramas × 1 image (poster only) = 4 requests at startup
    // CachedNetworkImage handles its own lazy loading for the rest
    final preloadList = dramas.take(4).toList();
    for (final drama in preloadList) {
      if (drama.posterImage.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(drama.posterImage), context);
      }
      // Removed bannerImage preload — only loaded when user opens hero slider
    }
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }
}
