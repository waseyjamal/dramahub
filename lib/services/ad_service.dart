import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'ad_config_service.dart';

class AdService extends GetxService {
  static AdService get instance => Get.find<AdService>();

  static const String _appKey = '25d9acedd';
  static const String _interstitialAdUnitId = '9376lcqwbkl99r6v';
  static const String _rewardedAdUnitId = '8ask2oenzoqbxo09';
  static const List<int> _retryBackoffSeconds = [10, 30, 60, 120];

  // ── Startup grace period ──────────────────────────────────────────────────
  static const int _startupGraceSeconds = 8;
  DateTime _appStartTime = DateTime.now();
  bool get _isInGracePeriod =>
      DateTime.now().difference(_appStartTime).inSeconds < _startupGraceSeconds;

  // ── Session tracking ──────────────────────────────────────────────────────
  int _interstitialShownCount = 0;
  DateTime? _lastInterstitialTime;
  DateTime _sessionStartTime = DateTime.now();
  int _rewardedShownCount = 0;
  DateTime? _lastRewardedTime;
  int _downloadShownCount = 0;
  DateTime? _lastDownloadTime;
  int _offlineAdShownCount = 0;
  DateTime? _lastOfflineAdTime;

  // ── Init and show guards ──────────────────────────────────────────────────
  bool _initialized = false;
  bool _adCurrentlyShowing = false;
  bool _interstitialShowing = false;
  bool _rewardedShowing = false;

  // ── LevelPlay ad objects ──────────────────────────────────────────────────
  LevelPlayInterstitialAd? _interstitialAd;
  LevelPlayRewardedAd? _rewardedAd;

  // ── Retry state ───────────────────────────────────────────────────────────
  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;
  int _interstitialRetryCount = 0;
  int _rewardedRetryCount = 0;

  AdConfigService get _cfg => AdConfigService.instance;

  // ── Public early-init — called from main.dart in Future.wait ─────────────
  Future<void> initLevelPlayEarly() async {
    if (!_cfg.config.adNetworks.levelplayEnabled) return;
    if (!_cfg.adsEnabled) return;
    await _initLevelPlay();
  }

  // ── Refresh on resume ─────────────────────────────────────────────────────
  Future<void> refreshAdLoad() async {
    if (!_initialized) return;
    if (!_cfg.config.adNetworks.levelplayEnabled) return;
    final interstitialReady = await _interstitialAd?.isAdReady() ?? false;
    if (!interstitialReady) _loadInterstitial();
    final rewardedReady = await _rewardedAd?.isAdReady() ?? false;
    if (!rewardedReady) _loadRewarded();
  }

  // ── LevelPlay init ────────────────────────────────────────────────────────
  Future<void> _initLevelPlay() async {
    try {
      final initRequest = LevelPlayInitRequest.builder(_appKey).build();
      await LevelPlay.init(
        initRequest: initRequest,
        initListener: _LevelPlayInitListener(
          onSuccess: () {
            _initialized = true;
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

  // ── Load Interstitial ─────────────────────────────────────────────────────
  void _loadInterstitial() {
    if (!_initialized) return;
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    _interstitialAd?.setListener(_InterstitialListener(onLoaded: () {}, onFailed: () {}));
    _interstitialAd = LevelPlayInterstitialAd(adUnitId: _interstitialAdUnitId);
    _interstitialAd!.setListener(_InterstitialListener(
      onLoaded: () {
        _interstitialRetryCount = 0;
        if (kDebugMode) debugPrint('✅ LevelPlay Interstitial loaded');
        _logAnalytics('interstitial_load_success');
      },
      onFailed: () {
        if (kDebugMode) debugPrint('❌ LevelPlay Interstitial failed to load');
        _logAnalytics('interstitial_load_failed');
        _scheduleInterstitialRetry();
      },
    ));
    _interstitialAd!.loadAd();
  }

  // ── Load Rewarded ─────────────────────────────────────────────────────────
  void _loadRewarded() {
    if (!_initialized) return;
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = null;
    _rewardedAd?.setListener(_RewardedListener(onLoaded: () {}, onFailed: () {}, onRewarded: () {}, onClosed: () {}));
    _rewardedAd = LevelPlayRewardedAd(adUnitId: _rewardedAdUnitId);
    _rewardedAd!.setListener(_RewardedListener(
      onLoaded: () {
        _rewardedRetryCount = 0;
        if (kDebugMode) debugPrint('✅ LevelPlay Rewarded loaded');
        _logAnalytics('rewarded_load_success');
      },
      onFailed: () {
        if (kDebugMode) debugPrint('❌ LevelPlay Rewarded failed to load');
        _logAnalytics('rewarded_load_failed');
        _scheduleRewardedRetry();
      },
      onRewarded: () {},
      onClosed: () {},
    ));
    _rewardedAd!.loadAd();
  }

  // ── Retry schedulers ──────────────────────────────────────────────────────
  void _scheduleInterstitialRetry() {
    if (_interstitialRetryCount >= _retryBackoffSeconds.length) return;
    final delay = _retryBackoffSeconds[_interstitialRetryCount];
    _interstitialRetryCount++;
    if (kDebugMode) {
      debugPrint(
        '⏱ Interstitial retry in ${delay}s (attempt $_interstitialRetryCount)',
      );
    }
    _interstitialRetryTimer = Timer(Duration(seconds: delay), _loadInterstitial);
  }

  void _scheduleRewardedRetry() {
    if (_rewardedRetryCount >= _retryBackoffSeconds.length) return;
    final delay = _retryBackoffSeconds[_rewardedRetryCount];
    _rewardedRetryCount++;
    if (kDebugMode) {
      debugPrint(
        '⏱ Rewarded retry in ${delay}s (attempt $_rewardedRetryCount)',
      );
    }
    _rewardedRetryTimer = Timer(Duration(seconds: delay), _loadRewarded);
  }

  // ── Session reset ─────────────────────────────────────────────────────────
  void _checkSessionReset() {
    final resetMinutes = _cfg.config.sessionResetMinutes;
    final diff = DateTime.now().difference(_sessionStartTime);
    if (diff.inMinutes >= resetMinutes) {
      _interstitialShownCount = 0;
      _rewardedShownCount = 0;
      _downloadShownCount = 0;
      _offlineAdShownCount = 0;
      _sessionStartTime = DateTime.now();
      if (kDebugMode) debugPrint('🔄 Ad session reset ($resetMinutes min)');
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

  // ── Firebase Analytics ────────────────────────────────────────────────────
  void _logAnalytics(String event, {Map<String, Object>? params}) {
    try {
      FirebaseAnalytics.instance.logEvent(name: 'ad_$event', parameters: params);
    } catch (_) {}
  }

  // ── Waterfall helper — Interstitial ───────────────────────────────────────
  Future<bool> _tryShowInterstitial(String provider) async {
    if (provider == 'levelplay' && _cfg.config.adNetworks.levelplayEnabled) {
      if (_interstitialShowing) return false;
      if (_interstitialAd == null) return false;
      final ready = await _interstitialAd!.isAdReady();
      if (!ready) {
        if (kDebugMode) debugPrint('ℹ️ LevelPlay Interstitial not ready');
        return false;
      }
      final completer = Completer<bool>();
      _interstitialShowing = true;
      _adCurrentlyShowing = true;
      _interstitialAd!.setListener(_InterstitialListener(
        onLoaded: () {},
        onFailed: () {},
        onClosed: () {
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
          _interstitialShowing = false;
          _adCurrentlyShowing = false;
          _logAnalytics('interstitial_shown', params: {'provider': 'levelplay'});
          if (!completer.isCompleted) completer.complete(true);
          _loadInterstitial();
        },
        onShowFailed: () {
          _interstitialShowing = false;
          _adCurrentlyShowing = false;
          if (!completer.isCompleted) completer.complete(false);
          _loadInterstitial();
        },
      ));
      try {
        await _interstitialAd!.showAd();
      } catch (e) {
        _interstitialShowing = false;
        _adCurrentlyShowing = false;
        if (!completer.isCompleted) completer.complete(false);
        if (kDebugMode) debugPrint('❌ Interstitial showAd() threw: $e');
        _loadInterstitial();
        return false;
      }
      return completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _interstitialShowing = false;
          _adCurrentlyShowing = false;
          return false;
        },
      );
    }
    return false;
  }

  // ── Waterfall helper — Rewarded ───────────────────────────────────────────
  Future<bool> _tryShowRewarded(
    String provider, {
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    if (provider == 'levelplay' && _cfg.config.adNetworks.levelplayEnabled) {
      if (_rewardedShowing) return false;
      if (_rewardedAd == null) return false;
      final ready = await _rewardedAd!.isAdReady();
      if (!ready) {
        if (kDebugMode) debugPrint('ℹ️ LevelPlay Rewarded not ready');
        return false;
      }
      bool rewardGranted = false;
      final completer = Completer<bool>();
      _rewardedShowing = true;
      _adCurrentlyShowing = true;
      _rewardedAd!.setListener(_RewardedListener(
        onLoaded: () {},
        onFailed: () {},
        onRewarded: () {
          rewardGranted = true;
          onRewarded();
          _logAnalytics('rewarded_granted', params: {'provider': 'levelplay'});
        },
        onClosed: () {
          _rewardedShowing = false;
          _adCurrentlyShowing = false;
          if (!rewardGranted) onNotAvailable?.call();
          if (!completer.isCompleted) completer.complete(rewardGranted);
          _loadRewarded();
        },
        onShowFailed: () {
          _rewardedShowing = false;
          _adCurrentlyShowing = false;
          onNotAvailable?.call();
          if (!completer.isCompleted) completer.complete(false);
          _loadRewarded();
        },
      ));
      try {
        await _rewardedAd!.showAd();
      } catch (e) {
        _rewardedShowing = false;
        _adCurrentlyShowing = false;
        onNotAvailable?.call();
        if (!completer.isCompleted) completer.complete(false);
        if (kDebugMode) debugPrint('❌ Rewarded showAd() threw: $e');
        _loadRewarded();
        return false;
      }
      return completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _rewardedShowing = false;
          _adCurrentlyShowing = false;
          return false;
        },
      );
    }
    return false;
  }

  // ── Show Interstitial ─────────────────────────────────────────────────────
  Future<void> showInterstitialForScreen(String screenKey) async {
    if (!_cfg.adsEnabled) return;
    if (!_cfg.canShowInterstitialOn(screenKey)) return;
    if (_isInGracePeriod) {
      if (kDebugMode) {
        debugPrint('ℹ️ Skipping interstitial on $screenKey — startup grace period');
      }
      return;
    }
    if (_adCurrentlyShowing) {
      if (kDebugMode) debugPrint('ℹ️ Skipping interstitial — ad already showing');
      return;
    }
    _checkSessionReset();

    final config = _cfg.config.interstitial;
    if (_interstitialShownCount >= config.maxPerSession) return;
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed.inSeconds < config.cooldownSeconds) return;
    }

    _logAnalytics('interstitial_attempt', params: {'screen': screenKey});

    if (config.priority1Enabled) {
      final shown = await _tryShowInterstitial(config.priority1);
      if (shown) {
        if (config.priority1 != 'levelplay') {
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
        }
        if (kDebugMode) {
          debugPrint('✅ Interstitial shown via ${config.priority1} (P1) on $screenKey');
        }
        return;
      }
    }

    if (config.priority2Enabled) {
      final shown = await _tryShowInterstitial(config.priority2);
      if (shown) {
        if (config.priority2 != 'levelplay') {
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
        }
        if (kDebugMode) {
          debugPrint('✅ Interstitial shown via ${config.priority2} (P2) on $screenKey');
        }
        return;
      }
    }

    _logAnalytics('interstitial_no_fill', params: {'screen': screenKey});
    if (kDebugMode) debugPrint('ℹ️ No Interstitial available on $screenKey');
  }

  // ── Show Rewarded ─────────────────────────────────────────────────────────
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
    if (_adCurrentlyShowing) {
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

    _logAnalytics('rewarded_attempt', params: {'screen': screenKey});

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
          debugPrint('✅ Rewarded shown via ${config.priority1} (P1) on $screenKey');
        }
        return;
      }
    }

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
          debugPrint('✅ Rewarded shown via ${config.priority2} (P2) on $screenKey');
        }
        return;
      }
    }

    _logAnalytics('rewarded_no_fill', params: {'screen': screenKey});
    if (kDebugMode) debugPrint('ℹ️ No Rewarded available on $screenKey');
    onNotAvailable?.call();
  }

  // ── Show Rewarded for Download ────────────────────────────────────────────
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
    if (_adCurrentlyShowing) {
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
          debugPrint('✅ Download rewarded shown via ${downloadConfig.priority1} (P1)');
        }
        return;
      }
    }

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
          debugPrint('✅ Download rewarded shown via ${downloadConfig.priority2} (P2)');
        }
        return;
      }
    }

    onNotAvailable?.call();
  }

  // ── Show Offline Ad ───────────────────────────────────────────────────────
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
    if (_adCurrentlyShowing) {
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

  // ── App Open — no provider available, no-op ───────────────────────────────
  Future<void> showAppOpen() async {}

  @override
  void onInit() {
    super.onInit();
    _appStartTime = DateTime.now();
    _sessionStartTime = DateTime.now();
  }

  @override
  void onClose() {
    _interstitialRetryTimer?.cancel();
    _rewardedRetryTimer?.cancel();
    super.onClose();
  }
}

// ── LevelPlay Listener Classes ────────────────────────────────────────────────

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
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    if (kDebugMode) debugPrint('❌ Interstitial display failed: $error');
    onShowFailed?.call();
  }
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
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    if (kDebugMode) debugPrint('❌ Rewarded display failed: $error');
    onShowFailed?.call();
  }
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
