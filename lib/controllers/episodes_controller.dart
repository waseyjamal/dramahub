import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/services/data_service.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/controllers/history_controller.dart';
import 'package:drama_hub/utils/constants.dart'; // ✅ StorageKeys
import 'package:drama_hub/services/analytics_writer_service.dart';
import 'dart:async';

class EpisodesController extends GetxController {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final DataService _dataService = Get.find<DataService>();
  final AdService _adService = Get.find<AdService>();

  final RxList<EpisodeModel> allEpisodes = <EpisodeModel>[].obs;
  final RxList<EpisodeModel> filteredEpisodes = <EpisodeModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasInternet = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  Timer? _searchDebounce;
  late DramaModel selectedDrama;
  bool skipInterstitialOnOpen = false;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is DramaModel) {
      selectedDrama = Get.arguments as DramaModel;
      skipInterstitialOnOpen = false;
      loadEpisodes();
      Future.delayed(const Duration(seconds: 1), () {
        _adService.showInterstitialForScreen('episodes_screen');
      });
    } else if (Get.arguments != null && Get.arguments is Map) {
      final args = Get.arguments as Map;
      final drama = args['drama'];
      if (drama == null || drama is! DramaModel) {
        debugPrint('EpisodesController: invalid drama in map — navigating back');
        Future.microtask(() => Get.back());
        return;
      }
      selectedDrama = drama;
      skipInterstitialOnOpen = args['skipAd'] == true;
      loadEpisodes();
      if (!skipInterstitialOnOpen) {
        Future.delayed(const Duration(seconds: 1), () {
          _adService.showInterstitialForScreen('episodes_screen');
        });
      }
    } else {
      debugPrint('EpisodesController: invalid arguments — navigating back');
      Future.microtask(() => Get.back());
    }
  }

  Future<void> loadEpisodes() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        hasInternet.value = false;
        isLoading.value = false;
        return;
      }

      hasInternet.value = true;
      final loadedEpisodes = await _dataService.loadEpisodes(selectedDrama.id);
      final List<EpisodeModel> safeList = List<EpisodeModel>.from(
        loadedEpisodes,
      );
      safeList.sort((a, b) => b.episodeNumber.compareTo(a.episodeNumber));
      allEpisodes.assignAll(safeList);
      filteredEpisodes.assignAll(safeList);
    } catch (e) {
      debugPrint('Error loading episodes: $e');
      hasError.value = true;
      errorMessage.value = 'Failed to load episodes. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveLastWatched(EpisodeModel episode) async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ StorageKeys replacing all magic strings
    await prefs.setString(StorageKeys.lastDramaId, selectedDrama.id);
    await prefs.setString(StorageKeys.lastDramaTitle, selectedDrama.title);
    await prefs.setString(
      StorageKeys.lastDramaBanner,
      selectedDrama.bannerImage,
    );
    await prefs.setInt(StorageKeys.lastEpisodeNumber, episode.episodeNumber);
    await prefs.setString(StorageKeys.lastEpisodeTitle, episode.title);

    final historyController = Get.find<HistoryController>();
    await historyController.addToHistory(
      dramaId: selectedDrama.id,
      dramaTitle: selectedDrama.title,
      dramaBanner: selectedDrama.bannerImage,
      episodeNumber: episode.episodeNumber,
      episodeTitle: episode.title,
    );
  }

  Future<void> openEpisode(EpisodeModel episode) async {
    if (episode.isUpcoming) {
      Get.toNamed(AppRoutes.upcoming, arguments: episode);
      return;
    }
    await saveLastWatched(episode);
    await _adService.showRewardedForScreen(
      'episodes_screen',
      onRewarded: () {},
      onNotAvailable: () {},
    );
    _analytics.logEvent(
      name: 'episode_watched',
      parameters: {
        'drama_id': selectedDrama.id,
        'drama_title': selectedDrama.title,
        'episode_number': episode.episodeNumber,
        'episode_title': episode.title,
      },
    );
    // ✅ Write to Firestore for admin analytics dashboard
    AnalyticsWriterService.instance.logEpisodeWatch(
      dramaId: selectedDrama.id,
      dramaTitle: selectedDrama.title,
      episodeId: episode.id,
      episodeTitle: episode.title,
      episodeNumber: episode.episodeNumber,
    );
    // ✅ Pass dramaTitle and dramaBanner for video screen display
    Get.toNamed(
      AppRoutes.video,
      arguments: {
        'episode': episode,
        'dramaTitle': selectedDrama.title,
        'dramaBanner': selectedDrama.bannerImage,
      },
    );
  }

  void filterEpisodes(String query) {
    // ✅ 5.9 — 300ms debounce
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        filteredEpisodes.assignAll(allEpisodes);
      } else {
        filteredEpisodes.assignAll(
          allEpisodes.where((e) {
            final q = query.toLowerCase();
            return e.title.toLowerCase().contains(q) ||
                e.episodeNumber.toString().contains(q);
          }).toList(),
        );
      }
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }
}
