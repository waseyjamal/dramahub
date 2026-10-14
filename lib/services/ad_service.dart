import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'ad_config_service.dart';

/// Outcome of a single rewarded show attempt.
enum _RewardedResult { notShown, shownRewarded, shownNotRewarded }

class AdService extends GetxService {
  static AdService get instance => Get.find<AdService>();

  static const String _appKey = '25d9acedd';
  static const String _interstitialAdUnitId = '9376lcqwbkl99r6v';
  static const String _rewardedAdUnitId = '8ask2oenzoqbxo09';
  // ── Shorts Ad Units (Separate from main app) ──────────────────────────────
  static const String _shortsInterstitialAdUnitId = 'drsrjo3zrab63yn4';
  static const String _shortsRewardedAdUnitId = 'au75oul4efg0l8x8';
  static const List<int> _retryBackoffSeconds = [10, 30, 60, 120];
  // After the backoff list is used up, keep retrying slowly all session
  static const int _slowRetrySeconds = 300;

  // ── Show timeouts ─────────────────────────────────────────────────────────
  // Only a failure to *display* times out quickly. Once the ad is on screen
  // we wait for onAdClosed; the long timeout is just a safety net.
  static const Duration _adDisplayTimeout = Duration(seconds: 5);
  static const Duration _adSafetyTimeout = Duration(minutes: 5);

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
  bool _interstitialLoading = false;
  bool _rewardedLoading = false;

  // ── LevelPlay ad objects (created once, reused for every load) ────────────
  LevelPlayInterstitialAd? _interstitialAd;
  LevelPlayRewardedAd? _rewardedAd;
  LevelPlayInterstitialAd? _shortsInterstitialAd;
  LevelPlayRewardedAd? _shortsRewardedAd;

  // ── Shorts show and load guards ───────────────────────────────────────────
  bool _shortsInterstitialShowing = false;
  bool _shortsRewardedShowing = false;
  bool _shortsInterstitialLoading = false;
  bool _shortsRewardedLoading = false;

  // ── Retry state ───────────────────────────────────────────────────────────
  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;
  int _interstitialRetryCount = 0;
  int _rewardedRetryCount = 0;
  Timer? _shortsInterstitialRetryTimer;
  Timer? _shortsRewardedRetryTimer;
  int _shortsInterstitialRetryCount = 0;
  int _shortsRewardedRetryCount = 0;

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
    final shortsInterstitialReady =
        await _shortsInterstitialAd?.isAdReady() ?? false;
    if (!shortsInterstitialReady) _loadShortsInterstitial();
    final shortsRewardedReady =
        await _shortsRewardedAd?.isAdReady() ?? false;
    if (!shortsRewardedReady) _loadShortsRewarded();
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
            _loadShortsInterstitial();
            _loadShortsRewarded();
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
    if (_interstitialShowing || _interstitialLoading) return;
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    final ad = _interstitialAd ??= LevelPlayInterstitialAd(
      adUnitId: _interstitialAdUnitId,
    );
    _interstitialLoading = true;
    ad.setListener(_InterstitialListener(
      onLoaded: () {
        _interstitialLoading = false;
        _interstitialRetryCount = 0;
        if (kDebugMode) debugPrint('✅ LevelPlay Interstitial loaded');
        _logAnalytics('interstitial_load_success');
      },
      onFailed: () {
        _interstitialLoading = false;
        if (kDebugMode) debugPrint('❌ LevelPlay Interstitial failed to load');
        _logAnalytics('interstitial_load_failed');
        _scheduleInterstitialRetry();
      },
    ));
    ad.loadAd();
  }

  // ── Load Rewarded ─────────────────────────────────────────────────────────
  void _loadRewarded() {
    if (!_initialized) return;
    if (_rewardedShowing || _rewardedLoading) return;
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = null;
    final ad = _rewardedAd ??= LevelPlayRewardedAd(adUnitId: _rewardedAdUnitId);
    _rewardedLoading = true;
    ad.setListener(_RewardedListener(
      onLoaded: () {
        _rewardedLoading = false;
        _rewardedRetryCount = 0;
        if (kDebugMode) debugPrint('✅ LevelPlay Rewarded loaded');
        _logAnalytics('rewarded_load_success');
      },
      onFailed: () {
        _rewardedLoading = false;
        if (kDebugMode) debugPrint('❌ LevelPlay Rewarded failed to load');
        _logAnalytics('rewarded_load_failed');
        _scheduleRewardedRetry();
      },
      onRewarded: () {},
      onClosed: () {},
    ));
    ad.loadAd();
  }

  // ── Retry schedulers ──────────────────────────────────────────────────────
  void _scheduleInterstitialRetry() {
    final delay = _interstitialRetryCount < _retryBackoffSeconds.length
        ? _retryBackoffSeconds[_interstitialRetryCount]
        : _slowRetrySeconds;
    _interstitialRetryCount++;
    if (kDebugMode) {
      debugPrint(
        '⏱ Interstitial retry in ${delay}s (attempt $_interstitialRetryCount)',
      );
    }
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = Timer(Duration(seconds: delay), _loadInterstitial);
  }

  void _scheduleRewardedRetry() {
    final delay = _rewardedRetryCount < _retryBackoffSeconds.length
        ? _retryBackoffSeconds[_rewardedRetryCount]
        : _slowRetrySeconds;
    _rewardedRetryCount++;
    if (kDebugMode) {
      debugPrint(
        '⏱ Rewarded retry in ${delay}s (attempt $_rewardedRetryCount)',
      );
    }
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = Timer(Duration(seconds: delay), _loadRewarded);
  }

  // ── Load Shorts Interstitial ──────────────────────────────────────────────
  void _loadShortsInterstitial() {
    if (!_initialized) return;
    if (!_cfg.config.adNetworks.levelplayEnabled) return;
    if (_shortsInterstitialShowing || _shortsInterstitialLoading) return;
    _shortsInterstitialRetryTimer?.cancel();
    _shortsInterstitialRetryTimer = null;
    final ad = _shortsInterstitialAd ??= LevelPlayInterstitialAd(
      adUnitId: _shortsInterstitialAdUnitId,
    );
    _shortsInterstitialLoading = true;
    ad.setListener(_InterstitialListener(
      onLoaded: () {
        _shortsInterstitialLoading = false;
        _shortsInterstitialRetryCount = 0;
        if (kDebugMode) debugPrint('✅ LevelPlay Shorts Interstitial loaded');
        _logAnalytics('shorts_interstitial_load_success');
      },
      onFailed: () {
        _shortsInterstitialLoading = false;
        if (kDebugMode) debugPrint('❌ LevelPlay Shorts Interstitial failed to load');
        _logAnalytics('shorts_interstitial_load_failed');
        _scheduleShortsInterstitialRetry();
      },
    ));
    ad.loadAd();
  }

  // ── Load Shorts Rewarded ──────────────────────────────────────────────────
  void _loadShortsRewarded() {
    if (!_initialized) return;
    if (!_cfg.config.adNetworks.levelplayEnabled) return;
    if (_shortsRewardedShowing || _shortsRewardedLoading) return;
    _shortsRewardedRetryTimer?.cancel();
    _shortsRewardedRetryTimer = null;
    final ad = _shortsRewardedAd ??= LevelPlayRewardedAd(
      adUnitId: _shortsRewardedAdUnitId,
    );
    _shortsRewardedLoading = true;
    ad.setListener(_RewardedListener(
      onLoaded: () {
        _shortsRewardedLoading = false;
        _shortsRewardedRetryCount = 0;
        if (kDebugMode) debugPrint('✅ LevelPlay Shorts Rewarded loaded');
        _logAnalytics('shorts_rewarded_load_success');
      },
      onFailed: () {
        _shortsRewardedLoading = false;
        if (kDebugMode) debugPrint('❌ LevelPlay Shorts Rewarded failed to load');
        _logAnalytics('shorts_rewarded_load_failed');
        _scheduleShortsRewardedRetry();
      },
      onRewarded: () {},
      onClosed: () {},
    ));
    ad.loadAd();
  }

  void _scheduleShortsInterstitialRetry() {
    final delay = _shortsInterstitialRetryCount < _retryBackoffSeconds.length
        ? _retryBackoffSeconds[_shortsInterstitialRetryCount]
        : _slowRetrySeconds;
    _shortsInterstitialRetryCount++;
    if (kDebugMode) {
      debugPrint(
        '⏱ Shorts Interstitial retry in ${delay}s (attempt $_shortsInterstitialRetryCount)',
      );
    }
    _shortsInterstitialRetryTimer?.cancel();
    _shortsInterstitialRetryTimer =
        Timer(Duration(seconds: delay), _loadShortsInterstitial);
  }

  void _scheduleShortsRewardedRetry() {
    final delay = _shortsRewardedRetryCount < _retryBackoffSeconds.length
        ? _retryBackoffSeconds[_shortsRewardedRetryCount]
        : _slowRetrySeconds;
    _shortsRewardedRetryCount++;
    if (kDebugMode) {
      debugPrint(
        '⏱ Shorts Rewarded retry in ${delay}s (attempt $_shortsRewardedRetryCount)',
      );
    }
    _shortsRewardedRetryTimer?.cancel();
    _shortsRewardedRetryTimer =
        Timer(Duration(seconds: delay), _loadShortsRewarded);
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
    if (provider != 'levelplay' || !_cfg.config.adNetworks.levelplayEnabled) {
      return false;
    }
    if (_interstitialShowing) return false;
    final ad = _interstitialAd;
    if (ad == null) return false;
    final ready = await ad.isAdReady();
    if (!ready) {
      if (kDebugMode) debugPrint('ℹ️ LevelPlay Interstitial not ready');
      return false;
    }

    final completer = Completer<bool>();
    Timer? displayTimer;
    Timer? safetyTimer;
    var displayed = false;

    void finish(bool shown) {
      displayTimer?.cancel();
      safetyTimer?.cancel();
      _interstitialShowing = false;
      _adCurrentlyShowing = false;
      if (!completer.isCompleted) completer.complete(shown);
    }

    _interstitialShowing = true;
    _adCurrentlyShowing = true;
    ad.setListener(_InterstitialListener(
      onLoaded: () {},
      onFailed: () {},
      onDisplayed: () {
        displayed = true;
        displayTimer?.cancel();
        safetyTimer?.cancel();
        safetyTimer = Timer(_adSafetyTimeout, () => finish(true));
      },
      onClosed: () {
        _interstitialShownCount++;
        _lastInterstitialTime = DateTime.now();
        _logAnalytics('interstitial_shown', params: {'provider': 'levelplay'});
        finish(true);
        _loadInterstitial();
      },
      onShowFailed: () {
        finish(false);
        _loadInterstitial();
      },
    ));
    displayTimer = Timer(_adDisplayTimeout, () {
      if (displayed) return;
      if (kDebugMode) debugPrint('⏱ Interstitial did not display in time');
      finish(false);
      _loadInterstitial();
    });
    try {
      await ad.showAd();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Interstitial showAd() threw: $e');
      finish(false);
      _loadInterstitial();
    }
    return completer.future;
  }

  // ── Waterfall helper — Rewarded ───────────────────────────────────────────
  /// Shows a rewarded ad and reports what happened. Never calls any
  /// caller callback itself — callers act on the result exactly once.
  Future<_RewardedResult> _tryShowRewarded(String provider) async {
    if (provider != 'levelplay' || !_cfg.config.adNetworks.levelplayEnabled) {
      return _RewardedResult.notShown;
    }
    if (_rewardedShowing) return _RewardedResult.notShown;
    final ad = _rewardedAd;
    if (ad == null) return _RewardedResult.notShown;
    final ready = await ad.isAdReady();
    if (!ready) {
      if (kDebugMode) debugPrint('ℹ️ LevelPlay Rewarded not ready');
      return _RewardedResult.notShown;
    }

    final completer = Completer<_RewardedResult>();
    Timer? displayTimer;
    Timer? safetyTimer;
    var displayed = false;
    var rewardGranted = false;

    _RewardedResult shownResult() => rewardGranted
        ? _RewardedResult.shownRewarded
        : _RewardedResult.shownNotRewarded;

    void finish(_RewardedResult result) {
      displayTimer?.cancel();
      safetyTimer?.cancel();
      _rewardedShowing = false;
      _adCurrentlyShowing = false;
      if (!completer.isCompleted) completer.complete(result);
    }

    _rewardedShowing = true;
    _adCurrentlyShowing = true;
    ad.setListener(_RewardedListener(
      onLoaded: () {},
      onFailed: () {},
      onDisplayed: () {
        displayed = true;
        displayTimer?.cancel();
        safetyTimer?.cancel();
        safetyTimer = Timer(_adSafetyTimeout, () => finish(shownResult()));
      },
      onRewarded: () {
        rewardGranted = true;
        _logAnalytics('rewarded_granted', params: {'provider': 'levelplay'});
      },
      onClosed: () {
        finish(shownResult());
        _loadRewarded();
      },
      onShowFailed: () {
        finish(_RewardedResult.notShown);
        _loadRewarded();
      },
    ));
    displayTimer = Timer(_adDisplayTimeout, () {
      if (displayed) return;
      if (kDebugMode) debugPrint('⏱ Rewarded did not display in time');
      finish(_RewardedResult.notShown);
      _loadRewarded();
    });
    try {
      await ad.showAd();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Rewarded showAd() threw: $e');
      finish(_RewardedResult.notShown);
      _loadRewarded();
    }
    return completer.future;
  }

  /// Runs the P1 → P2 rewarded waterfall. Returns the first result where an
  /// ad was actually displayed, or [_RewardedResult.notShown].
  Future<_RewardedResult> _runRewardedWaterfall({
    required String priority1,
    required bool priority1Enabled,
    required String priority2,
    required bool priority2Enabled,
  }) async {
    var result = _RewardedResult.notShown;
    if (priority1Enabled) {
      result = await _tryShowRewarded(priority1);
    }
    if (result == _RewardedResult.notShown && priority2Enabled) {
      result = await _tryShowRewarded(priority2);
    }
    return result;
  }

  // ── Show Interstitial ─────────────────────────────────────────────────────
  Future<void> showInterstitialForScreen(String screenKey) async {
    if (screenKey == 'shorts_feed') {
      await showShortsInterstitial();
      return;
    }
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
    if (screenKey == 'shorts_unlock') {
      await showShortsRewarded(
        onRewarded: onRewarded,
        onNotAvailable: onNotAvailable,
      );
      return;
    }
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

    final result = await _runRewardedWaterfall(
      priority1: config.priority1,
      priority1Enabled: config.priority1Enabled,
      priority2: config.priority2,
      priority2Enabled: config.priority2Enabled,
    );

    // Any displayed ad (even skipped) counts toward cooldown and caps
    if (result != _RewardedResult.notShown) {
      _rewardedShownCount++;
      _lastRewardedTime = DateTime.now();
      if (kDebugMode) debugPrint('✅ Rewarded shown on $screenKey ($result)');
    } else {
      _logAnalytics('rewarded_no_fill', params: {'screen': screenKey});
      if (kDebugMode) debugPrint('ℹ️ No Rewarded available on $screenKey');
    }

    // Exactly one callback per call
    if (result == _RewardedResult.shownRewarded) {
      onRewarded();
    } else {
      onNotAvailable?.call();
    }
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

    final result = await _runRewardedWaterfall(
      priority1: downloadConfig.priority1,
      priority1Enabled: downloadConfig.priority1Enabled,
      priority2: downloadConfig.priority2,
      priority2Enabled: downloadConfig.priority2Enabled,
    );

    // Any displayed ad (even skipped) counts toward cooldown and caps
    if (result != _RewardedResult.notShown) {
      _downloadShownCount++;
      _lastDownloadTime = DateTime.now();
      if (kDebugMode) debugPrint('✅ Download rewarded shown ($result)');
    }

    // Exactly one callback per call
    if (result == _RewardedResult.shownRewarded) {
      onRewarded();
    } else {
      onNotAvailable?.call();
    }
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
      final result = await _runRewardedWaterfall(
        priority1: offlineCfg.priority1,
        priority1Enabled: offlineCfg.priority1Enabled,
        priority2: offlineCfg.priority2,
        priority2Enabled: offlineCfg.priority2Enabled,
      );
      adShown = result != _RewardedResult.notShown;
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

  // ── Preload Shorts Ads ────────────────────────────────────────────────────
  void preloadShortsAds() {
    if (!_initialized) return;
    if (!_cfg.config.adNetworks.levelplayEnabled) return;
    if (_shortsInterstitialAd == null) {
      _loadShortsInterstitial();
    } else {
      _shortsInterstitialAd!.isAdReady().then((ready) {
        if (!ready && !_shortsInterstitialLoading) _loadShortsInterstitial();
      });
    }
    if (_shortsRewardedAd == null) {
      _loadShortsRewarded();
    } else {
      _shortsRewardedAd!.isAdReady().then((ready) {
        if (!ready && !_shortsRewardedLoading) _loadShortsRewarded();
      });
    }
  }

  // ── Show Shorts Interstitial ──────────────────────────────────────────────
  Future<bool> showShortsInterstitial() async {
    if (!_cfg.adsEnabled || !_cfg.config.adNetworks.levelplayEnabled) {
      return false;
    }
    if (_isInGracePeriod) {
      if (kDebugMode) {
        debugPrint('ℹ️ Skipping shorts interstitial — startup grace period');
      }
      return false;
    }
    if (_adCurrentlyShowing || _shortsInterstitialShowing) {
      if (kDebugMode) {
        debugPrint('ℹ️ Skipping shorts interstitial — ad already showing');
      }
      return false;
    }

    final ad = _shortsInterstitialAd;
    if (ad == null) {
      _loadShortsInterstitial();
      return false;
    }

    var ready = await ad.isAdReady();
    if (!ready && _shortsInterstitialLoading) {
      // Brief grace wait if an ad is already in-flight from preload
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (await ad.isAdReady()) {
          ready = true;
          break;
        }
        if (!_shortsInterstitialLoading) break;
      }
    }

    if (!ready) {
      if (kDebugMode) debugPrint('ℹ️ LevelPlay Shorts Interstitial not ready');
      _loadShortsInterstitial();
      return false;
    }

    _logAnalytics('shorts_interstitial_attempt');

    final completer = Completer<bool>();
    Timer? displayTimer;
    Timer? safetyTimer;
    var displayed = false;

    void finish(bool shown) {
      displayTimer?.cancel();
      safetyTimer?.cancel();
      _shortsInterstitialShowing = false;
      _adCurrentlyShowing = false;
      if (!completer.isCompleted) completer.complete(shown);
    }

    _shortsInterstitialShowing = true;
    _adCurrentlyShowing = true;

    ad.setListener(_InterstitialListener(
      onLoaded: () {},
      onFailed: () {},
      onDisplayed: () {
        displayed = true;
        displayTimer?.cancel();
        safetyTimer?.cancel();
        safetyTimer = Timer(_adSafetyTimeout, () => finish(true));
      },
      onClosed: () {
        _logAnalytics(
          'shorts_interstitial_shown',
          params: {'provider': 'levelplay'},
        );
        finish(true);
        _loadShortsInterstitial();
      },
      onShowFailed: () {
        finish(false);
        _loadShortsInterstitial();
      },
    ));

    displayTimer = Timer(_adDisplayTimeout, () {
      if (displayed) return;
      if (kDebugMode) debugPrint('⏱ Shorts Interstitial did not display in time');
      finish(false);
      _loadShortsInterstitial();
    });

    try {
      await ad.showAd();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Shorts Interstitial showAd() threw: $e');
      finish(false);
      _loadShortsInterstitial();
    }

    return completer.future;
  }

  // ── Show Shorts Rewarded ──────────────────────────────────────────────────
  Future<void> showShortsRewarded({
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    if (!_cfg.adsEnabled || !_cfg.config.adNetworks.levelplayEnabled) {
      onNotAvailable?.call();
      return;
    }
    if (_adCurrentlyShowing || _shortsRewardedShowing) {
      onNotAvailable?.call();
      return;
    }

    final ad = _shortsRewardedAd;
    if (ad == null) {
      _loadShortsRewarded();
      onNotAvailable?.call();
      return;
    }

    var ready = await ad.isAdReady();
    if (!ready && _shortsRewardedLoading) {
      // Brief grace wait (up to 1.5s) if rewarded ad is already in-flight from preload
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (await ad.isAdReady()) {
          ready = true;
          break;
        }
        if (!_shortsRewardedLoading) break;
      }
    }

    if (!ready) {
      if (kDebugMode) debugPrint('ℹ️ LevelPlay Shorts Rewarded not ready');
      _loadShortsRewarded();
      onNotAvailable?.call();
      return;
    }

    _logAnalytics('shorts_rewarded_attempt');

    final completer = Completer<_RewardedResult>();
    Timer? displayTimer;
    Timer? safetyTimer;
    var displayed = false;
    var rewardGranted = false;

    _RewardedResult shownResult() => rewardGranted
        ? _RewardedResult.shownRewarded
        : _RewardedResult.shownNotRewarded;

    void finish(_RewardedResult result) {
      displayTimer?.cancel();
      safetyTimer?.cancel();
      _shortsRewardedShowing = false;
      _adCurrentlyShowing = false;
      if (!completer.isCompleted) completer.complete(result);
    }

    _shortsRewardedShowing = true;
    _adCurrentlyShowing = true;

    ad.setListener(_RewardedListener(
      onLoaded: () {},
      onFailed: () {},
      onDisplayed: () {
        displayed = true;
        displayTimer?.cancel();
        safetyTimer?.cancel();
        safetyTimer = Timer(_adSafetyTimeout, () => finish(shownResult()));
      },
      onRewarded: () {
        rewardGranted = true;
        _logAnalytics(
          'shorts_rewarded_granted',
          params: {'provider': 'levelplay'},
        );
      },
      onClosed: () {
        finish(shownResult());
        _loadShortsRewarded();
      },
      onShowFailed: () {
        finish(_RewardedResult.notShown);
        _loadShortsRewarded();
      },
    ));

    displayTimer = Timer(_adDisplayTimeout, () {
      if (displayed) return;
      if (kDebugMode) debugPrint('⏱ Shorts Rewarded did not display in time');
      finish(_RewardedResult.notShown);
      _loadShortsRewarded();
    });

    try {
      await ad.showAd();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Shorts Rewarded showAd() threw: $e');
      finish(_RewardedResult.notShown);
      _loadShortsRewarded();
    }

    final result = await completer.future;
    if (result == _RewardedResult.shownRewarded) {
      _logAnalytics('shorts_rewarded_shown');
      onRewarded();
    } else {
      _logAnalytics('shorts_rewarded_no_fill');
      onNotAvailable?.call();
    }
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
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
    _shortsInterstitialRetryTimer?.cancel();
    _shortsRewardedRetryTimer?.cancel();
    _shortsInterstitialAd?.dispose();
    _shortsRewardedAd?.dispose();
    _shortsInterstitialAd = null;
    _shortsRewardedAd = null;
    super.onClose();
  }
}

// ── LevelPlay Listener Classes ────────────────────────────────────────────────

class _InterstitialListener with LevelPlayInterstitialAdListener {
  final VoidCallback onLoaded;
  final VoidCallback onFailed;
  final VoidCallback? onDisplayed;
  final VoidCallback? onClosed;
  final VoidCallback? onShowFailed;

  _InterstitialListener({
    required this.onLoaded,
    required this.onFailed,
    this.onDisplayed,
    this.onClosed,
    this.onShowFailed,
  });

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded();
  @override
  void onAdLoadFailed(LevelPlayAdError error) => onFailed();
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => onDisplayed?.call();
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
  final VoidCallback? onDisplayed;
  final VoidCallback onRewarded;
  final VoidCallback onClosed;
  final VoidCallback? onShowFailed;

  _RewardedListener({
    required this.onLoaded,
    required this.onFailed,
    this.onDisplayed,
    required this.onRewarded,
    required this.onClosed,
    this.onShowFailed,
  });

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded();
  @override
  void onAdLoadFailed(LevelPlayAdError error) => onFailed();
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => onDisplayed?.call();
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
