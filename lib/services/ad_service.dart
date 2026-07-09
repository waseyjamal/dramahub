import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:drama_hub/services/cas_service.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'ad_config_service.dart';

class AdService extends GetxService {
  static AdService get instance => Get.find<AdService>();

  static const String _appKey = '25d9acedd';

  int _interstitialShownCount = 0;
  DateTime? _lastInterstitialTime;
  DateTime _sessionStartTime = DateTime.now();
  int _rewardedShownCount = 0;
  DateTime? _lastRewardedTime;
  int _downloadShownCount = 0;
  DateTime? _lastDownloadTime;

  // ✅ Offline ads — completely separate counters
  int _offlineAdShownCount = 0;
  DateTime? _lastOfflineAdTime;

  AdConfigService get _cfg => AdConfigService.instance;

  void _checkSessionReset() {
    final diff = DateTime.now().difference(_sessionStartTime);
    if (diff.inHours >= 4) {
      _interstitialShownCount = 0;
      _sessionStartTime = DateTime.now();
      if (kDebugMode) {
        debugPrint('🔄 Ad session reset');
      }
    }
  }

  void resetSession() {
    _interstitialShownCount = 0;
    _lastInterstitialTime = null;
    _rewardedShownCount = 0;
    _lastRewardedTime = null;
    _downloadShownCount = 0;
    _lastDownloadTime = null;
    _offlineAdShownCount = 0;
    _lastOfflineAdTime = null;
    _sessionStartTime = DateTime.now();
  }

  // ── LevelPlay interstitial ad unit ──
  LevelPlayInterstitialAd? _interstitialAd;
  static const String _interstitialAdUnitId = '9376lcqwbkl99r6v';

  // ── LevelPlay rewarded ad unit ──
  LevelPlayRewardedAd? _rewardedAd;
  static const String _rewardedAdUnitId = '8ask2oenzoqbxo09';

  Future<void> _initLevelPlay() async {
    try {
      final initRequest = LevelPlayInitRequest.builder(_appKey).build();
      await LevelPlay.init(
        initRequest: initRequest,
        initListener: _LevelPlayInitListener(
          onSuccess: () {
            if (kDebugMode) debugPrint('✅ LevelPlay initialized');
            _loadInterstitial();
            _loadRewarded();
          },
          onFailed: (error) {
            if (kDebugMode) debugPrint('❌ LevelPlay init failed: $error');
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ LevelPlay init error: $e');
    }
  }

  void _loadInterstitial() {
    _interstitialAd = LevelPlayInterstitialAd(adUnitId: _interstitialAdUnitId);
    _interstitialAd!.setListener(
      _InterstitialListener(
        onLoaded: () {
          if (kDebugMode) debugPrint('✅ LevelPlay Interstitial loaded');
        },
        onFailed: () {
          if (kDebugMode) debugPrint('❌ LevelPlay Interstitial failed to load');
        },
      ),
    );
    _interstitialAd!.loadAd();
  }

  void _loadRewarded() {
    _rewardedAd = LevelPlayRewardedAd(adUnitId: _rewardedAdUnitId);
    _rewardedAd!.setListener(
      _RewardedListener(
        onLoaded: () {
          if (kDebugMode) debugPrint('✅ LevelPlay Rewarded loaded');
        },
        onFailed: () {
          if (kDebugMode) debugPrint('❌ LevelPlay Rewarded failed to load');
        },
        onRewarded: () {},
        onClosed: () {},
      ),
    );
    _rewardedAd!.loadAd();
  }

  Future<void> showInterstitialForScreen(String screenKey) async {
    if (!_cfg.adsEnabled) return;
    if (!_cfg.canShowInterstitialOn(screenKey)) return;
    _checkSessionReset();

    final config = _cfg.config.interstitial;
    if (_interstitialShownCount >= config.maxPerSession) return;
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed.inSeconds < config.cooldownSeconds) return;
    }

    if (config.priority1Enabled &&
        config.priority1 == 'levelplay' &&
        _cfg.config.adNetworks.levelplayEnabled) {
      if (_interstitialAd != null && await _interstitialAd!.isAdReady()) {
        final completer = Completer<void>();
        _interstitialAd!.setListener(
          _InterstitialListener(
            onLoaded: () {},
            onFailed: () {},
            onClosed: () {
              if (!completer.isCompleted) completer.complete();
              _loadInterstitial();
            },
            onShowFailed: () {
              if (!completer.isCompleted) completer.complete();
            },
          ),
        );
        await _interstitialAd!.showAd();
        await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {},
        );
        _interstitialShownCount++;
        _lastInterstitialTime = DateTime.now();
        if (kDebugMode) {
          debugPrint('✅ Interstitial shown via LevelPlay on $screenKey');
        }
        return;
      }
      if (kDebugMode) debugPrint('ℹ️ LevelPlay Interstitial not ready');
    }

    if (config.priority2Enabled &&
        config.priority2 == 'cas' &&
        _cfg.config.adNetworks.casEnabled) {
      final shown = await CasService.instance.showInterstitialFallback();
      if (shown) {
        _interstitialShownCount++;
        _lastInterstitialTime = DateTime.now();
        if (kDebugMode) {
          debugPrint('✅ Interstitial shown via CAS on $screenKey');
        }
        return;
      }
    }

    if (kDebugMode) debugPrint('ℹ️ No Interstitial available on $screenKey');
  }

  Future<void> showRewardedForScreen(
    String screenKey, {
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    if (!_cfg.adsEnabled) {
      onNotAvailable?.call();
      return;
    }
    if (!_cfg.canShowRewardedOn(screenKey)) {
      onNotAvailable?.call();
      return;
    }
    _checkSessionReset();

    final config = _cfg.config.rewarded;
    if (_rewardedShownCount >= config.maxPerSession) {
      onNotAvailable?.call();
      return;
    }
    if (_lastRewardedTime != null) {
      final elapsed = DateTime.now().difference(_lastRewardedTime!);
      if (elapsed.inSeconds < config.cooldownSeconds) {
        onNotAvailable?.call();
        return;
      }
    }

    if (config.priority1Enabled &&
        config.priority1 == 'levelplay' &&
        _cfg.config.adNetworks.levelplayEnabled) {
      if (_rewardedAd != null && await _rewardedAd!.isAdReady()) {
        bool rewardGranted = false;
        final completer = Completer<void>();
        _rewardedAd!.setListener(
          _RewardedListener(
            onLoaded: () {},
            onFailed: () {},
            onRewarded: () {
              rewardGranted = true;
              onRewarded();
            },
            onClosed: () {
              if (!rewardGranted) onNotAvailable?.call();
              if (!completer.isCompleted) completer.complete();
              _loadRewarded();
            },
            onShowFailed: () {
              onNotAvailable?.call();
              if (!completer.isCompleted) completer.complete();
            },
          ),
        );
        await _rewardedAd!.showAd();
        await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {},
        );
        _rewardedShownCount++;
        _lastRewardedTime = DateTime.now();
        if (kDebugMode) {
          debugPrint('✅ Rewarded shown via LevelPlay on $screenKey');
        }
        return;
      }
      if (kDebugMode) debugPrint('ℹ️ LevelPlay Rewarded not ready');
    }

    if (config.priority2Enabled &&
        config.priority2 == 'cas' &&
        _cfg.config.adNetworks.casEnabled) {
      final shown = await CasService.instance.showRewardedFallback(
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
      if (shown) {
        _rewardedShownCount++;
        _lastRewardedTime = DateTime.now();
        if (kDebugMode) debugPrint('✅ Rewarded shown via CAS on $screenKey');
        return;
      }
    }

    if (kDebugMode) debugPrint('ℹ️ No Rewarded available on $screenKey');
    onNotAvailable?.call();
  }

  Future<void> showRewardedForDownload({
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    if (!_cfg.adsEnabled) {
      onNotAvailable?.call();
      return;
    }
    final downloadConfig = _cfg.config.download;
    if (!downloadConfig.enabled) {
      onNotAvailable?.call();
      return;
    }
    _checkSessionReset();
    if (_downloadShownCount >= downloadConfig.maxPerSession) {
      onNotAvailable?.call();
      return;
    }
    if (_lastDownloadTime != null) {
      final elapsed = DateTime.now().difference(_lastDownloadTime!);
      if (elapsed.inSeconds < downloadConfig.cooldownSeconds) {
        onNotAvailable?.call();
        return;
      }
    }

    if (downloadConfig.priority1Enabled &&
        downloadConfig.priority1 == 'levelplay' &&
        _cfg.config.adNetworks.levelplayEnabled) {
      if (_rewardedAd != null && await _rewardedAd!.isAdReady()) {
        bool rewardGranted = false;
        final completer = Completer<void>();
        _rewardedAd!.setListener(
          _RewardedListener(
            onLoaded: () {},
            onFailed: () {},
            onRewarded: () {
              rewardGranted = true;
              onRewarded();
            },
            onClosed: () {
              if (!rewardGranted) onNotAvailable?.call();
              if (!completer.isCompleted) completer.complete();
              _loadRewarded();
            },
            onShowFailed: () {
              onNotAvailable?.call();
              if (!completer.isCompleted) completer.complete();
            },
          ),
        );
        await _rewardedAd!.showAd();
        await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {},
        );
        _downloadShownCount++;
        _lastDownloadTime = DateTime.now();
        if (kDebugMode) debugPrint('✅ Download rewarded shown via LevelPlay');
        return;
      }
    }

    if (downloadConfig.priority2Enabled &&
        downloadConfig.priority2 == 'cas' &&
        _cfg.config.adNetworks.casEnabled) {
      final shown = await CasService.instance.showRewardedFallback(
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
      if (shown) {
        _downloadShownCount++;
        _lastDownloadTime = DateTime.now();
        return;
      }
    }

    onNotAvailable?.call();
  }

  Future<void> showOfflineAd({required VoidCallback onComplete}) async {
    if (!_cfg.adsEnabled) {
      onComplete();
      return;
    }
    final offlineCfg = _cfg.offlineAds;
    if (!offlineCfg.enabled) {
      onComplete();
      return;
    }
    _checkSessionReset();
    if (_lastOfflineAdTime != null) {
      final elapsed = DateTime.now().difference(_lastOfflineAdTime!);
      if (elapsed.inMinutes < offlineCfg.sessionCoolMinutes) {
        onComplete();
        return;
      }
    }
    if (_offlineAdShownCount >= offlineCfg.maxPerSession) {
      onComplete();
      return;
    }

    if (offlineCfg.adType == 'rewarded') {
      if (_rewardedAd != null && await _rewardedAd!.isAdReady()) {
        final completer = Completer<void>();
        _rewardedAd!.setListener(
          _RewardedListener(
            onLoaded: () {},
            onFailed: () {},
            onRewarded: () {},
            onClosed: () {
              if (!completer.isCompleted) completer.complete();
              _loadRewarded();
            },
            onShowFailed: () {
              if (!completer.isCompleted) completer.complete();
            },
          ),
        );
        await _rewardedAd!.showAd();
        await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {},
        );
        _offlineAdShownCount++;
        _lastOfflineAdTime = DateTime.now();
      }
    } else {
      if (_interstitialAd != null && await _interstitialAd!.isAdReady()) {
        final completer = Completer<void>();
        _interstitialAd!.setListener(
          _InterstitialListener(
            onLoaded: () {},
            onFailed: () {},
            onClosed: () {
              if (!completer.isCompleted) completer.complete();
              _loadInterstitial();
            },
            onShowFailed: () {
              if (!completer.isCompleted) completer.complete();
            },
          ),
        );
        await _interstitialAd!.showAd();
        await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {},
        );
        _offlineAdShownCount++;
        _lastOfflineAdTime = DateTime.now();
      }
    }
    onComplete();
  }

  Future<void> showAppOpen() async {
    // App Open disabled — no supported Flutter SDK for direct Liftoff calls
    // Will be enabled when official Flutter plugin becomes available
  }

  @override
  void onInit() {
    super.onInit();
    _sessionStartTime = DateTime.now();
    if (_cfg.adsEnabled) {
      _initLevelPlay();
    }
  }
}

class _InterstitialListener with LevelPlayInterstitialAdListener {
  final VoidCallback onLoaded;
  final VoidCallback onFailed;
  final VoidCallback? onClosed;
  final VoidCallback? onShowFailed;

  _InterstitialListener({
    required this.onLoaded,
    required this.onFailed,
    this.onClosed,
    this.onShowFailed,
  });

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded();
  @override
  void onAdLoadFailed(LevelPlayAdError error) => onFailed();
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) =>
      onShowFailed?.call();
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => onClosed?.call();
  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}

class _RewardedListener with LevelPlayRewardedAdListener {
  final VoidCallback onLoaded;
  final VoidCallback onFailed;
  final VoidCallback onRewarded;
  final VoidCallback onClosed;
  final VoidCallback? onShowFailed;

  _RewardedListener({
    required this.onLoaded,
    required this.onFailed,
    required this.onRewarded,
    required this.onClosed,
    this.onShowFailed,
  });

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded();
  @override
  void onAdLoadFailed(LevelPlayAdError error) => onFailed();
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) =>
      onShowFailed?.call();
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => onClosed();
  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) =>
      onRewarded();
}

class _LevelPlayInitListener with LevelPlayInitListener {
  final VoidCallback onSuccess;
  final void Function(LevelPlayInitError?) onFailed;

  _LevelPlayInitListener({required this.onSuccess, required this.onFailed});

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) => onSuccess();

  @override
  void onInitFailed(LevelPlayInitError error) => onFailed(error);
}
