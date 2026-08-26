// lib/services/yandex_service.dart
// ============================================================
// YANDEX EASY MONETIZATION SERVICE
// Replaces CAS.ai as the Priority 2 (fallback) ad network.
// Handles: Interstitial, Rewarded, App Open
// Native ads are handled separately by YandexBannerAdWidget.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import 'ad_config_service.dart';

class YandexService extends GetxService {
  static YandexService get instance => Get.find<YandexService>();

  // ── Real Ad Unit IDs (from Yandex Easy Monetization setup) ──────
  static const String _interstitialAdUnitId = 'R-M-19564249-1';
  static const String _rewardedAdUnitId = 'R-M-19564249-2';
  static const String _appOpenAdUnitId = 'R-M-19564249-8';

  // ── Internal state ───────────────────────────────────────────────
  bool _initialized = false;

  // ── Ad expiry tracking ───────────────────────────────────────────
  static const Duration _adMaxAge = Duration(minutes: 55);

  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;
  bool _interstitialShowing = false;
  DateTime? _interstitialLoadedAt;
  int _interstitialRetryAttempt = 0;
  Timer? _interstitialRetryTimer;

  RewardedAd? _rewardedAd;
  bool _rewardedReady = false;
  bool _rewardedShowing = false;
  DateTime? _rewardedLoadedAt;
  int _rewardedRetryAttempt = 0;
  Timer? _rewardedRetryTimer;

  AppOpenAd? _appOpenAd;
  bool _appOpenReady = false;
  int _appOpenRetryAttempt = 0;
  Timer? _appOpenRetryTimer;

  static const List<int> _retryBackoffSeconds = [10, 30, 60, 120];

  bool _appOpenShowing = false;
  bool _pendingAppOpenShow = false;
  bool _hasShownThisSession = false;
  bool _returnedFromBackground = false;
  DateTime? _lastAppOpenTime;
  DateTime? _lastAdClosedTime;
  bool _navigationOccurred = false;

  AdConfigService get _cfg => AdConfigService.instance;

  // ── Initialization ───────────────────────────────────────────────
  // Called from main.dart inside Future.wait([...]) during splash.
  // MobileAds.initialize() is already called in main.dart before this.
  Future<void> initEarly() async {
    if (!_cfg.adsEnabled) return;
    if (!_cfg.config.adNetworks.yandexEnabled) return;
    try {
      _initialized = true;
      _loadInterstitial();
      _loadRewarded();
      if (_cfg.config.appOpen.enabled &&
          _cfg.config.appOpen.provider == 'yandex') {
        _loadAppOpen();
      }
      if (kDebugMode) debugPrint('✅ YandexService initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ YandexService init error: $e');
    }
  }

  // ── Load Interstitial ────────────────────────────────────────────
  void _loadInterstitial() {
    if (!_initialized) return;
    _interstitialRetryTimer?.cancel();
    try {
      final loader = InterstitialAdLoader();
      loader.loadAd(
        adRequest: AdRequest(
          adUnitId: kDebugMode
              ? 'demo-interstitial-yandex'
              : _interstitialAdUnitId,
        ),
      ).then((ad) {
        _interstitialAd = ad;
        _interstitialReady = true;
        _interstitialLoadedAt = DateTime.now();
        _interstitialRetryAttempt = 0;
        if (kDebugMode) debugPrint('✅ Yandex Interstitial loaded');
      }).catchError((e) {
        _interstitialReady = false;
        _scheduleInterstitialRetry();
        if (kDebugMode) debugPrint('❌ Yandex Interstitial load failed: $e');
      });
    } catch (e) {
      _interstitialReady = false;
      _scheduleInterstitialRetry();
      if (kDebugMode) debugPrint('❌ Yandex Interstitial load error: $e');
    }
  }

  void _scheduleInterstitialRetry() {
    final delay = _retryBackoffSeconds[
        _interstitialRetryAttempt.clamp(0, _retryBackoffSeconds.length - 1)];
    _interstitialRetryAttempt++;
    _interstitialRetryTimer =
        Timer(Duration(seconds: delay), _loadInterstitial);
    if (kDebugMode) {
      debugPrint('🔄 Interstitial retry in ${delay}s (attempt $_interstitialRetryAttempt)');
    }
  }

  // ── Load Rewarded ────────────────────────────────────────────────
  void _loadRewarded() {
    if (!_initialized) return;
    _rewardedRetryTimer?.cancel();
    try {
      final loader = RewardedAdLoader();
      loader.loadAd(
        adRequest: AdRequest(
          adUnitId: kDebugMode
              ? 'demo-rewarded-yandex'
              : _rewardedAdUnitId,
        ),
      ).then((ad) {
        _rewardedAd = ad;
        _rewardedReady = true;
        _rewardedLoadedAt = DateTime.now();
        _rewardedRetryAttempt = 0;
        if (kDebugMode) debugPrint('✅ Yandex Rewarded loaded');
      }).catchError((e) {
        _rewardedReady = false;
        _scheduleRewardedRetry();
        if (kDebugMode) debugPrint('❌ Yandex Rewarded load failed: $e');
      });
    } catch (e) {
      _rewardedReady = false;
      _scheduleRewardedRetry();
      if (kDebugMode) debugPrint('❌ Yandex Rewarded load error: $e');
    }
  }

  void _scheduleRewardedRetry() {
    final delay = _retryBackoffSeconds[
        _rewardedRetryAttempt.clamp(0, _retryBackoffSeconds.length - 1)];
    _rewardedRetryAttempt++;
    _rewardedRetryTimer = Timer(Duration(seconds: delay), _loadRewarded);
    if (kDebugMode) {
      debugPrint('🔄 Rewarded retry in ${delay}s (attempt $_rewardedRetryAttempt)');
    }
  }

  // ── Load App Open ────────────────────────────────────────────────
  void _loadAppOpen() {
    if (!_initialized) return;
    try {
      final loader = AppOpenAdLoader();
      loader.loadAd(
        adRequest: AdRequest(
          adUnitId: kDebugMode
              ? 'demo-appopenad-yandex'
              : _appOpenAdUnitId,
        ),
      ).then((ad) {
        _appOpenAd = ad;
        _appOpenReady = true;
        if (kDebugMode) debugPrint('✅ Yandex App Open loaded');
        if (_pendingAppOpenShow) {
          _pendingAppOpenShow = false;
          showAppOpen();
        }
      }).catchError((e) {
        _appOpenReady = false;
        _pendingAppOpenShow = false;
        _scheduleAppOpenRetry();
        if (kDebugMode) debugPrint('❌ Yandex App Open load failed: $e');
      });
    } catch (e) {
      _appOpenReady = false;
      _scheduleAppOpenRetry();
      if (kDebugMode) debugPrint('❌ Yandex App Open load error: $e');
    }
  }

  void _scheduleAppOpenRetry() {
    final delay = _retryBackoffSeconds[
        _appOpenRetryAttempt.clamp(0, _retryBackoffSeconds.length - 1)];
    _appOpenRetryAttempt++;
    _appOpenRetryTimer = Timer(Duration(seconds: delay), _loadAppOpen);
    if (kDebugMode) {
      debugPrint('🔄 AppOpen retry in ${delay}s (attempt $_appOpenRetryAttempt)');
    }
  }

  // ── Show Interstitial (called from AdService waterfall) ──────────
  Future<bool> showInterstitialFallback() async {
    if (!_initialized) return false;
    if (_interstitialShowing) return false;
    // ── Expiry check — refresh stale ad before show-time failure ────
    if (_interstitialReady && _interstitialLoadedAt != null) {
      if (DateTime.now().difference(_interstitialLoadedAt!) > _adMaxAge) {
        if (kDebugMode) debugPrint('⚠️ Interstitial expired — reloading');
        _interstitialReady = false;
        _interstitialAd?.destroy();
        _interstitialAd = null;
        _loadInterstitial();
      }
    }
    if (!_interstitialReady || _interstitialAd == null) {
      if (kDebugMode) debugPrint('ℹ️ Yandex Interstitial not ready');
      return false;
    }

    final completer = Completer<bool>();
    _interstitialReady = false;
    _interstitialShowing = true;

    _interstitialAd!.setAdEventListener(
      eventListener: InterstitialAdEventListener(
        onAdShown: () {
          if (kDebugMode) debugPrint('▶️ Yandex Interstitial shown');
        },
        onAdDismissed: () {
          _interstitialShowing = false;
          recordAdClosed();
          if (!completer.isCompleted) completer.complete(true);
          _interstitialAd?.destroy();
          _interstitialAd = null;
          _loadInterstitial();
        },
        onAdClicked: () {},
        onAdFailedToShow: (error) {
          _interstitialShowing = false;
          if (kDebugMode) {
            debugPrint(
              '❌ Yandex Interstitial failed to show: ${error.description}',
            );
          }
          if (!completer.isCompleted) completer.complete(false);
          _interstitialAd?.destroy();
          _interstitialAd = null;
          _loadInterstitial();
        },
        onAdImpression: (_) {},
      ),
    );

    await _interstitialAd!.show();
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _interstitialShowing = false;
        return false;
      },
    );
  }

  // ── Show Rewarded (called from AdService waterfall) ──────────────
  Future<bool> showRewardedFallback({
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    if (!_initialized) {
      onNotAvailable?.call();
      return false;
    }
    if (_rewardedShowing) {
      return true;
    }
    // ── Expiry check ─────────────────────────────────────────────────
    if (_rewardedReady && _rewardedLoadedAt != null) {
      if (DateTime.now().difference(_rewardedLoadedAt!) > _adMaxAge) {
        if (kDebugMode) debugPrint('⚠️ Rewarded expired — reloading');
        _rewardedReady = false;
        _rewardedAd?.destroy();
        _rewardedAd = null;
        _loadRewarded();
      }
    }
    if (!_rewardedReady || _rewardedAd == null) {
      if (kDebugMode) debugPrint('ℹ️ Yandex Rewarded not ready');
      onNotAvailable?.call();
      return false;
    }

    bool rewardGranted = false;
    final completer = Completer<bool>();
    _rewardedReady = false;
    _rewardedShowing = true;

    _rewardedAd!.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () {
          if (kDebugMode) debugPrint('▶️ Yandex Rewarded shown');
        },
        onAdDismissed: () {
          _rewardedShowing = false;
          recordAdClosed();
          if (!rewardGranted) onNotAvailable?.call();
          _rewardedAd?.destroy();
          _rewardedAd = null;
          _loadRewarded();
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdClicked: () {},
        onAdFailedToShow: (error) {
          _rewardedShowing = false;
          if (kDebugMode) {
            debugPrint(
              '❌ Yandex Rewarded failed to show: ${error.description}',
            );
          }
          onNotAvailable?.call();
          _rewardedAd?.destroy();
          _rewardedAd = null;
          _loadRewarded();
          if (!completer.isCompleted) completer.complete(false);
        },
        onAdImpression: (_) {},
        onRewarded: (reward) {
          if (kDebugMode) {
            debugPrint(
              '🎁 Yandex Reward earned: ${reward.amount} ${reward.type}',
            );
          }
          rewardGranted = true;
          onRewarded();
        },
      ),
    );

    await _rewardedAd!.show();
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _rewardedShowing = false;
        if (kDebugMode) {
          debugPrint('⚠️ Yandex Rewarded timed out');
        }
        return false;
      },
    );
  }

  void recordAdClosed() {
    _lastAdClosedTime = DateTime.now();
    if (kDebugMode) debugPrint('ℹ️ Ad closed — App Open blocked for 5 seconds');
  }

  void setReturnedFromBackground() {
    if (_lastAdClosedTime != null) {
      final elapsed = DateTime.now().difference(_lastAdClosedTime!);
      if (elapsed.inSeconds < 5) {
        if (kDebugMode) debugPrint('ℹ️ App Open blocked — ad just closed');
        return;
      }
    }
    _navigationOccurred = false;
    _returnedFromBackground = true;
    if (kDebugMode) debugPrint('ℹ️ App returned from background — App Open allowed');
  }

  void onUserNavigated() {
    _navigationOccurred = true;
    _pendingAppOpenShow = false;
    if (kDebugMode) debugPrint('ℹ️ Navigation occurred — App Open blocked until next background return');
  }

  // ── Cancel pending App Open if user navigates away from home ─────
  void cancelPendingAppOpen() {
    if (_pendingAppOpenShow) {
      _pendingAppOpenShow = false;
      if (kDebugMode) debugPrint('ℹ️ Yandex App Open pending cancelled — user navigated');
    }
  }

  // ── Show App Open (called from AdService / main.dart) ────────────
  Future<void> showAppOpen() async {
    if (!_initialized) return;
    if (!_cfg.config.appOpen.enabled) return;
    if (_cfg.config.appOpen.provider != 'yandex') return;
    if (_navigationOccurred) {
      if (kDebugMode) debugPrint('ℹ️ App Open blocked — user already navigated');
      return;
    }
    if (!_appOpenReady || _appOpenAd == null) {
      if (kDebugMode) debugPrint('ℹ️ Yandex App Open not ready — will show when loaded');
      _pendingAppOpenShow = true;
      return;
    }
    if (_hasShownThisSession && !_returnedFromBackground) return;
    _returnedFromBackground = false;
    if (_appOpenShowing) return;

    // Cooldown check
    if (_lastAppOpenTime != null) {
      final elapsed = DateTime.now().difference(_lastAppOpenTime!);
      if (elapsed.inSeconds < _cfg.config.appOpen.cooldownSeconds) {
        if (kDebugMode) debugPrint('ℹ️ Yandex App Open cooldown active');
        return;
      }
    }

    _appOpenShowing = true;
    _appOpenReady = false;

    // ✅ FIX 4: Safety timer — if onAdDismissed never fires, release the lock
    // after 60s so App Open can show again next session
    Future.delayed(const Duration(seconds: 60), () {
      if (_appOpenShowing) {
        _appOpenShowing = false;
        if (kDebugMode) {
          debugPrint('⚠️ App Open stuck lock released after timeout');
        }
      }
    });

    _appOpenAd!.setAdEventListener(
      eventListener: AppOpenAdEventListener(
        onAdShown: () {
          _lastAppOpenTime = DateTime.now();
          _hasShownThisSession = true;
          if (kDebugMode) debugPrint('▶️ Yandex App Open shown');
        },
        onAdDismissed: () {
          _appOpenShowing = false;
          _appOpenAd?.destroy();
          _appOpenAd = null;
          _loadAppOpen();
          if (kDebugMode) debugPrint('✅ Yandex App Open dismissed');
        },
        onAdClicked: () {},
        onAdFailedToShow: (error) {
          _appOpenShowing = false;
          if (kDebugMode) {
            debugPrint(
              '❌ Yandex App Open failed to show: ${error.description}',
            );
          }
          _appOpenAd?.destroy();
          _appOpenAd = null;
          _loadAppOpen();
        },
        onAdImpression: (_) {},
      ),
    );

    await _appOpenAd!.show();
  }

  // ── Called when admin enables Yandex remotely ───────────────────
  // AdConfigService.refresh() is called on app resume — call this after
  void refreshAdLoad() {
    if (!_cfg.config.adNetworks.yandexEnabled) return;
    if (!_initialized) {
      _initialized = true;
    }
    _loadInterstitial();
    _loadRewarded();
    if (_cfg.config.appOpen.enabled &&
        _cfg.config.appOpen.provider == 'yandex') {
      _loadAppOpen();
    }
  }

  @override
  void onClose() {
    _interstitialRetryTimer?.cancel();
    _rewardedRetryTimer?.cancel();
    _appOpenRetryTimer?.cancel();
    _interstitialAd?.destroy();
    _rewardedAd?.destroy();
    _appOpenAd?.destroy();
    super.onClose();
  }
}