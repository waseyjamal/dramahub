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

      // ✅ Version check — clears all caches if data_version bumped
      final newVersion = AppConfigService.instance.config.dataVersion;
      final savedVersion = prefs.getInt(StorageKeys.dataVersion) ?? 0;
      if (newVersion != savedVersion) {
        debugPrint(
          'data_version changed $savedVersion → $newVersion — clearing all caches',
        );
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
          debugPrint('Drama cache hit — ${cached.length} dramas');
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
                debugPrint('Episode load failed for ${drama.id}: $e');
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

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }
}
