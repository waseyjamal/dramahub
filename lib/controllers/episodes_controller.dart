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
import 'package:drama_hub/utils/constants.dart';
import 'dart:async';
import 'package:drama_hub/controllers/video_controller.dart';

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
  bool _isOpeningEpisode = false;
  late DramaModel selectedDrama;
  bool skipInterstitialOnOpen = false;

  // Coming Soon countdown
  final RxInt csDays = 0.obs;
  final RxInt csHours = 0.obs;
  final RxInt csMinutes = 0.obs;
  final RxInt csSeconds = 0.obs;
  final RxBool isComingSoonActive = false.obs;
  Timer? _countdownTimer;

  bool get isComingSoonDrama => selectedDrama.isComingSoon &&
      selectedDrama.premiereDate != null &&
      selectedDrama.premiereDate!.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is DramaModel) {
      selectedDrama = Get.arguments as DramaModel;
      skipInterstitialOnOpen = false;
      _initScreen();
      Future.delayed(const Duration(seconds: 1), () {
        _adService.showInterstitialForScreen('episodes_screen');
      });
    } else if (Get.arguments != null && Get.arguments is Map) {
      final args = Get.arguments as Map;
      final drama = args['drama'];
      if (drama == null || drama is! DramaModel) {
        if (kDebugMode) {
          debugPrint(
            'EpisodesController: invalid drama in map — navigating back',
          );
        }
        Future.microtask(() => Get.back());
        return;
      }
      selectedDrama = drama;
      skipInterstitialOnOpen = args['skipAd'] == true;
      final autoPlayEp = args['autoPlayEpisode'] as int?;

      _initScreen().then((_) {
        if (autoPlayEp != null) {
          final episode = allEpisodes.firstWhereOrNull(
            (e) => e.episodeNumber == autoPlayEp,
          );
          if (episode != null) openEpisode(episode);
        }
      });

      if (!skipInterstitialOnOpen && autoPlayEp == null) {
        Future.delayed(const Duration(seconds: 1), () {
          _adService.showInterstitialForScreen('episodes_screen');
        });
      }
    } else {
      if (kDebugMode) {
        debugPrint('EpisodesController: invalid arguments — navigating back');
      }
      Future.microtask(() => Get.back());
    }
  }

  Future<void> _initScreen() async {
    if (isComingSoonDrama) {
      // Check if premiere date already passed
      final premiere = DateTime.tryParse(selectedDrama.premiereDate!);
      if (premiere != null && DateTime.now().isBefore(premiere)) {
        isComingSoonActive.value = true;
        _startCountdown(premiere);
      } else {
        // Premiere date passed — treat as normal drama
        isComingSoonActive.value = false;
        await loadEpisodes();
      }
    } else {
      isComingSoonActive.value = false;
      await loadEpisodes();
    }
  }

  void _startCountdown(DateTime premiere) {
    _updateCountdown(premiere);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown(premiere);
    });
  }

  void _updateCountdown(DateTime premiere) {
    final diff = premiere.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds <= 0) {
      _countdownTimer?.cancel();
      isComingSoonActive.value = false;
      // Auto load episodes when timer hits zero
      loadEpisodes();
      return;
    }
    csDays.value = diff.inDays;
    csHours.value = diff.inHours % 24;
    csMinutes.value = diff.inMinutes % 60;
    csSeconds.value = diff.inSeconds % 60;
  }

  Future<void> loadEpisodes() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
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
      if (kDebugMode) {
        debugPrint('Error loading episodes: $e');
      }
      hasError.value = true;
      errorMessage.value = 'Failed to load episodes. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveLastWatched(EpisodeModel episode) async {
    final prefs = await SharedPreferences.getInstance();
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
    if (_isOpeningEpisode) return;
    _isOpeningEpisode = true;
    try {
      if (episode.isUpcoming) {
        Get.toNamed(AppRoutes.upcoming, arguments: episode);
        return;
      }
      await saveLastWatched(episode);
      await _adService.showRewardedForScreen(
        'episodes_screen',
        onRewarded: () => _navigateToVideo(episode),
        onNotAvailable: () => _navigateToVideo(episode),
      );
    } finally {
      _isOpeningEpisode = false;
    }
  }

  void _navigateToVideo(EpisodeModel episode) {
    _analytics.logEvent(
      name: 'episode_watched',
      parameters: {
        'drama_id': selectedDrama.id,
        'drama_title': selectedDrama.title,
        'episode_number': episode.episodeNumber,
        'episode_title': episode.title,
      },
    );
    Get.delete<VideoController>(force: true);
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
    _countdownTimer?.cancel();
    super.onClose();
  }
}