// lib/services/ad_service.dart
// ✅ LevelPlay fully commented out — restore by uncommenting all
//    // [LEVELPLAY] blocks and uncommenting unity_levelplay_mediation in pubspec.yaml

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:drama_hub/services/yandex_service.dart';
// [LEVELPLAY] import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'ad_config_service.dart';

class AdService extends GetxService {
  static AdService get instance => Get.find<AdService>();

  // [LEVELPLAY] static const String _appKey = '25d9acedd';

  // ── Startup grace period ─────────────────────────────────────────
  static const int _startupGraceSeconds = 8;
  DateTime _appStartTime = DateTime.now();

  bool get _isInGracePeriod =>
      DateTime.now().difference(_appStartTime).inSeconds < _startupGraceSeconds;

  int _interstitialShownCount = 0;
  DateTime? _lastInterstitialTime;
  DateTime _sessionStartTime = DateTime.now();
  int _rewardedShownCount = 0;
  DateTime? _lastRewardedTime;
  int _downloadShownCount = 0;
  DateTime? _lastDownloadTime;

  int _offlineAdShownCount = 0;
  DateTime? _lastOfflineAdTime;

  AdConfigService get _cfg => AdConfigService.instance;

  void _checkSessionReset() {
    final diff = DateTime.now().difference(_sessionStartTime);
    if (diff.inMinutes >= 90) {
      _interstitialShownCount = 0;
      _rewardedShownCount = 0;
      _downloadShownCount = 0;
      _offlineAdShownCount = 0;
      _sessionStartTime = DateTime.now();
      if (kDebugMode) debugPrint('🔄 Ad session reset (90 min)');
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

  // ── LevelPlay ad units ───────────────────────────────────────────
  // [LEVELPLAY] LevelPlayInterstitialAd? _interstitialAd;
  // [LEVELPLAY] static const String _interstitialAdUnitId = '9376lcqwbkl99r6v';
  // [LEVELPLAY] LevelPlayRewardedAd? _rewardedAd;
  // [LEVELPLAY] static const String _rewardedAdUnitId = '8ask2oenzoqbxo09';

  // [LEVELPLAY] Future<void> _initLevelPlay() async {
  // [LEVELPLAY]   try {
  // [LEVELPLAY]     final initRequest = LevelPlayInitRequest.builder(_appKey).build();
  // [LEVELPLAY]     await LevelPlay.init(
  // [LEVELPLAY]       initRequest: initRequest,
  // [LEVELPLAY]       initListener: _LevelPlayInitListener(
  // [LEVELPLAY]         onSuccess: () {
  // [LEVELPLAY]           if (kDebugMode) debugPrint('✅ LevelPlay initialized');
  // [LEVELPLAY]           _loadInterstitial();
  // [LEVELPLAY]           _loadRewarded();
  // [LEVELPLAY]         },
  // [LEVELPLAY]         onFailed: (error) {
  // [LEVELPLAY]           if (kDebugMode) debugPrint('❌ LevelPlay init failed: $error');
  // [LEVELPLAY]         },
  // [LEVELPLAY]       ),
  // [LEVELPLAY]     );
  // [LEVELPLAY]   } catch (e) {
  // [LEVELPLAY]     if (kDebugMode) debugPrint('❌ LevelPlay init error: $e');
  // [LEVELPLAY]   }
  // [LEVELPLAY] }

  // [LEVELPLAY] void _loadInterstitial() {
  // [LEVELPLAY]   _interstitialAd = LevelPlayInterstitialAd(adUnitId: _interstitialAdUnitId);
  // [LEVELPLAY]   _interstitialAd!.setListener(
  // [LEVELPLAY]     _InterstitialListener(
  // [LEVELPLAY]       onLoaded: () {
  // [LEVELPLAY]         if (kDebugMode) debugPrint('✅ LevelPlay Interstitial loaded');
  // [LEVELPLAY]       },
  // [LEVELPLAY]       onFailed: () {
  // [LEVELPLAY]         if (kDebugMode) debugPrint('❌ LevelPlay Interstitial failed to load');
  // [LEVELPLAY]       },
  // [LEVELPLAY]     ),
  // [LEVELPLAY]   );
  // [LEVELPLAY]   _interstitialAd!.loadAd();
  // [LEVELPLAY] }

  // [LEVELPLAY] void _loadRewarded() {
  // [LEVELPLAY]   _rewardedAd = LevelPlayRewardedAd(adUnitId: _rewardedAdUnitId);
  // [LEVELPLAY]   _rewardedAd!.setListener(
  // [LEVELPLAY]     _RewardedListener(
  // [LEVELPLAY]       onLoaded: () {
  // [LEVELPLAY]         if (kDebugMode) debugPrint('✅ LevelPlay Rewarded loaded');
  // [LEVELPLAY]       },
  // [LEVELPLAY]       onFailed: () {
  // [LEVELPLAY]         if (kDebugMode) debugPrint('❌ LevelPlay Rewarded failed to load');
  // [LEVELPLAY]       },
  // [LEVELPLAY]       onRewarded: () {},
  // [LEVELPLAY]       onClosed: () {},
  // [LEVELPLAY]     ),
  // [LEVELPLAY]   );
  // [LEVELPLAY]   _rewardedAd!.loadAd();
  // [LEVELPLAY] }

  // ── Core waterfall helper — Interstitial ─────────────────────────
  Future<bool> _tryShowInterstitial(String provider) async {
    // [LEVELPLAY] if (provider == 'levelplay' && _cfg.config.adNetworks.levelplayEnabled) {
    // [LEVELPLAY]   if (_interstitialAd != null && await _interstitialAd!.isAdReady()) {
    // [LEVELPLAY]     final completer = Completer<bool>();
    // [LEVELPLAY]     _interstitialAd!.setListener(
    // [LEVELPLAY]       _InterstitialListener(
    // [LEVELPLAY]         onLoaded: () {},
    // [LEVELPLAY]         onFailed: () {},
    // [LEVELPLAY]         onClosed: () {
    // [LEVELPLAY]           _interstitialShownCount++;
    // [LEVELPLAY]           _lastInterstitialTime = DateTime.now();
    // [LEVELPLAY]           if (!completer.isCompleted) completer.complete(true);
    // [LEVELPLAY]           _loadInterstitial();
    // [LEVELPLAY]         },
    // [LEVELPLAY]         onShowFailed: () {
    // [LEVELPLAY]           if (!completer.isCompleted) completer.complete(false);
    // [LEVELPLAY]         },
    // [LEVELPLAY]       ),
    // [LEVELPLAY]     );
    // [LEVELPLAY]     await _interstitialAd!.showAd();
    // [LEVELPLAY]     return completer.future.timeout(
    // [LEVELPLAY]       const Duration(seconds: 30),
    // [LEVELPLAY]       onTimeout: () => false,
    // [LEVELPLAY]     );
    // [LEVELPLAY]   }
    // [LEVELPLAY]   if (kDebugMode) debugPrint('ℹ️ LevelPlay Interstitial not ready');
    // [LEVELPLAY]   return false;
    // [LEVELPLAY] }

    if (provider == 'yandex' && _cfg.config.adNetworks.yandexEnabled) {
      return YandexService.instance.showInterstitialFallback();
    }

    return false;
  }

  // ── Core waterfall helper — Rewarded ─────────────────────────────
  Future<bool> _tryShowRewarded(
    String provider, {
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    // [LEVELPLAY] if (provider == 'levelplay' && _cfg.config.adNetworks.levelplayEnabled) {
    // [LEVELPLAY]   if (_rewardedAd != null && await _rewardedAd!.isAdReady()) {
    // [LEVELPLAY]     bool rewardGranted = false;
    // [LEVELPLAY]     final completer = Completer<bool>();
    // [LEVELPLAY]     _rewardedAd!.setListener(
    // [LEVELPLAY]       _RewardedListener(
    // [LEVELPLAY]         onLoaded: () {},
    // [LEVELPLAY]         onFailed: () {},
    // [LEVELPLAY]         onRewarded: () {
    // [LEVELPLAY]           rewardGranted = true;
    // [LEVELPLAY]           onRewarded();
    // [LEVELPLAY]         },
    // [LEVELPLAY]         onClosed: () {
    // [LEVELPLAY]           if (!rewardGranted) onNotAvailable?.call();
    // [LEVELPLAY]           if (!completer.isCompleted) completer.complete(rewardGranted);
    // [LEVELPLAY]           _loadRewarded();
    // [LEVELPLAY]         },
    // [LEVELPLAY]         onShowFailed: () {
    // [LEVELPLAY]           onNotAvailable?.call();
    // [LEVELPLAY]           if (!completer.isCompleted) completer.complete(false);
    // [LEVELPLAY]         },
    // [LEVELPLAY]       ),
    // [LEVELPLAY]     );
    // [LEVELPLAY]     await _rewardedAd!.showAd();
    // [LEVELPLAY]     await completer.future.timeout(
    // [LEVELPLAY]       const Duration(seconds: 60),
    // [LEVELPLAY]       onTimeout: () => false,
    // [LEVELPLAY]     );
    // [LEVELPLAY]     return true;
    // [LEVELPLAY]   }
    // [LEVELPLAY]   if (kDebugMode) debugPrint('ℹ️ LevelPlay Rewarded not ready');
    // [LEVELPLAY]   return false;
    // [LEVELPLAY] }

    if (provider == 'yandex' && _cfg.config.adNetworks.yandexEnabled) {
      return YandexService.instance.showRewardedFallback(
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
    }

    return false;
  }

  // ── Show Interstitial ────────────────────────────────────────────
  Future<void> showInterstitialForScreen(String screenKey) async {
    if (!_cfg.adsEnabled) return;
    if (!_cfg.canShowInterstitialOn(screenKey)) return;
    if (_isInGracePeriod) {
      if (kDebugMode) {
        debugPrint(
          'ℹ️ Skipping interstitial on $screenKey — startup grace period',
        );
      }
      return;
    }
    _checkSessionReset();

    final config = _cfg.config.interstitial;
    if (_interstitialShownCount >= config.maxPerSession) return;
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed.inSeconds < config.cooldownSeconds) return;
    }

    // ── Priority 1 ────────────────────────────────────────────────
    if (config.priority1Enabled) {
      final shown = await _tryShowInterstitial(config.priority1);
      if (shown) {
        if (config.priority1 != 'levelplay') {
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
        }
        if (kDebugMode) {
          debugPrint(
            '✅ Interstitial shown via ${config.priority1} (P1) on $screenKey',
          );
        }
        return;
      }
    }

    // ── Priority 2 ────────────────────────────────────────────────
    if (config.priority2Enabled) {
      final shown = await _tryShowInterstitial(config.priority2);
      if (shown) {
        if (config.priority2 != 'levelplay') {
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
        }
        if (kDebugMode) {
          debugPrint(
            '✅ Interstitial shown via ${config.priority2} (P2) on $screenKey',
          );
        }
        return;
      }
    }

    if (kDebugMode) debugPrint('ℹ️ No Interstitial available on $screenKey');
  }

  // ── Show Rewarded ────────────────────────────────────────────────
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

    // ── Priority 1 ────────────────────────────────────────────────
    if (config.priority1Enabled) {
      final shown = await _tryShowRewarded(
        config.priority1,
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
      if (shown) {
        _rewardedShownCount++;
        _lastRewardedTime = DateTime.now();
        if (kDebugMode) {
          debugPrint(
            '✅ Rewarded shown via ${config.priority1} (P1) on $screenKey',
          );
        }
        return;
      }
    }

    // ── Priority 2 ────────────────────────────────────────────────
    if (config.priority2Enabled) {
      final shown = await _tryShowRewarded(
        config.priority2,
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
      if (shown) {
        _rewardedShownCount++;
        _lastRewardedTime = DateTime.now();
        if (kDebugMode) {
          debugPrint(
            '✅ Rewarded shown via ${config.priority2} (P2) on $screenKey',
          );
        }
        return;
      }
    }

    if (kDebugMode) debugPrint('ℹ️ No Rewarded available on $screenKey');
    onNotAvailable?.call();
  }

  // ── Show Rewarded for Download ───────────────────────────────────
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

    // ── Priority 1 ────────────────────────────────────────────────
    if (downloadConfig.priority1Enabled) {
      final shown = await _tryShowRewarded(
        downloadConfig.priority1,
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
      if (shown) {
        _downloadShownCount++;
        _lastDownloadTime = DateTime.now();
        if (kDebugMode) {
          debugPrint(
            '✅ Download rewarded shown via ${downloadConfig.priority1} (P1)',
          );
        }
        return;
      }
    }

    // ── Priority 2 ────────────────────────────────────────────────
    if (downloadConfig.priority2Enabled) {
      final shown = await _tryShowRewarded(
        downloadConfig.priority2,
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
      if (shown) {
        _downloadShownCount++;
        _lastDownloadTime = DateTime.now();
        if (kDebugMode) {
          debugPrint(
            '✅ Download rewarded shown via ${downloadConfig.priority2} (P2)',
          );
        }
        return;
      }
    }

    onNotAvailable?.call();
  }

  // ── Show Offline Ad ──────────────────────────────────────────────
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

    bool adShown = false;

    if (offlineCfg.adType == 'rewarded') {
      if (offlineCfg.priority1Enabled) {
        adShown = await _tryShowRewarded(
          offlineCfg.priority1,
          onRewarded: () {},
          onNotAvailable: () {},
        );
      }
      if (!adShown && offlineCfg.priority2Enabled) {
        adShown = await _tryShowRewarded(
          offlineCfg.priority2,
          onRewarded: () {},
          onNotAvailable: () {},
        );
      }
    } else {
      if (offlineCfg.priority1Enabled) {
        adShown = await _tryShowInterstitial(offlineCfg.priority1);
      }
      if (!adShown && offlineCfg.priority2Enabled) {
        adShown = await _tryShowInterstitial(offlineCfg.priority2);
      }
    }

    if (adShown) {
      _offlineAdShownCount++;
      _lastOfflineAdTime = DateTime.now();
    }

    onComplete();
  }

  // ── Show App Open ────────────────────────────────────────────────
  Future<void> showAppOpen() async {
    if (!_cfg.adsEnabled) return;
    if (!_cfg.config.appOpen.enabled) return;
    if (_cfg.config.appOpen.provider == 'yandex') {
      await YandexService.instance.showAppOpen();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _appStartTime = DateTime.now();
    _sessionStartTime = DateTime.now();
    // [LEVELPLAY] if (_cfg.adsEnabled) {
    // [LEVELPLAY]   _initLevelPlay();
    // [LEVELPLAY] }
  }
}

// ── LevelPlay Listeners ──────────────────────────────────────────────────────
// [LEVELPLAY] class _InterstitialListener with LevelPlayInterstitialAdListener {
// [LEVELPLAY]   final VoidCallback onLoaded;
// [LEVELPLAY]   final VoidCallback onFailed;
// [LEVELPLAY]   final VoidCallback? onClosed;
// [LEVELPLAY]   final VoidCallback? onShowFailed;
// [LEVELPLAY]
// [LEVELPLAY]   _InterstitialListener({
// [LEVELPLAY]     required this.onLoaded,
// [LEVELPLAY]     required this.onFailed,
// [LEVELPLAY]     this.onClosed,
// [LEVELPLAY]     this.onShowFailed,
// [LEVELPLAY]   });
// [LEVELPLAY]
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdLoadFailed(LevelPlayAdError error) => onFailed();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdDisplayed(LevelPlayAdInfo adInfo) {}
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) =>
// [LEVELPLAY]       onShowFailed?.call();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdClicked(LevelPlayAdInfo adInfo) {}
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdClosed(LevelPlayAdInfo adInfo) => onClosed?.call();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
// [LEVELPLAY] }
// [LEVELPLAY]
// [LEVELPLAY] class _RewardedListener with LevelPlayRewardedAdListener {
// [LEVELPLAY]   final VoidCallback onLoaded;
// [LEVELPLAY]   final VoidCallback onFailed;
// [LEVELPLAY]   final VoidCallback onRewarded;
// [LEVELPLAY]   final VoidCallback onClosed;
// [LEVELPLAY]   final VoidCallback? onShowFailed;
// [LEVELPLAY]
// [LEVELPLAY]   _RewardedListener({
// [LEVELPLAY]     required this.onLoaded,
// [LEVELPLAY]     required this.onFailed,
// [LEVELPLAY]     required this.onRewarded,
// [LEVELPLAY]     required this.onClosed,
// [LEVELPLAY]     this.onShowFailed,
// [LEVELPLAY]   });
// [LEVELPLAY]
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdLoadFailed(LevelPlayAdError error) => onFailed();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdDisplayed(LevelPlayAdInfo adInfo) {}
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) =>
// [LEVELPLAY]       onShowFailed?.call();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdClicked(LevelPlayAdInfo adInfo) {}
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdClosed(LevelPlayAdInfo adInfo) => onClosed();
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) =>
// [LEVELPLAY]       onRewarded();
// [LEVELPLAY] }
// [LEVELPLAY]
// [LEVELPLAY] class _LevelPlayInitListener with LevelPlayInitListener {
// [LEVELPLAY]   final VoidCallback onSuccess;
// [LEVELPLAY]   final void Function(LevelPlayInitError?) onFailed;
// [LEVELPLAY]
// [LEVELPLAY]   _LevelPlayInitListener({required this.onSuccess, required this.onFailed});
// [LEVELPLAY]
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onInitSuccess(LevelPlayConfiguration configuration) => onSuccess();
// [LEVELPLAY]
// [LEVELPLAY]   @override
// [LEVELPLAY]   void onInitFailed(LevelPlayInitError error) => onFailed(error);
// [LEVELPLAY] }
