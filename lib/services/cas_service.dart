import 'dart:async';
import 'package:clever_ads_solutions/clever_ads_solutions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'ad_config_service.dart';
import 'package:drama_hub/routes/app_routes.dart';

class CasService extends GetxService {
  static CasService get instance => Get.find<CasService>();

  static const String _casId = 'com.dramahub.drama_hub';

  CASAppOpen? _appOpenAd;
  CASInterstitial? _casInterstitial;
  CASRewarded? _casRewarded;

  bool _casInitialized = false;
  bool _appOpenAdLoaded = false;
  bool _interstitialAdLoaded = false;
  bool _rewardedAdLoaded = false;
  bool _coldStartAdShown = false;
  DateTime? _lastAppOpenTime;
  Completer<void>? _casInitCompleter;

  AdConfigService get _cfg => AdConfigService.instance;

  /// Called from main.dart during splash — before runApp
  Future<void> initEarly() async {
    if (!_cfg.adsEnabled) return;
    _casInitCompleter = Completer<void>();
    _initCas();
    return _casInitCompleter!.future;
  }

  Future<void> _initCas() async {
    try {
      await CASMobileAds.initialize(
        casId: _casId,
        forceTestAds: kDebugMode,
      ).then((InitializationStatus status) {
        if (status.error != null) {
          if (kDebugMode) {
            debugPrint('❌ CAS init failed: ${status.error}');
          }
          if (_casInitCompleter != null && !_casInitCompleter!.isCompleted) {
            _casInitCompleter!.complete();
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('✅ CAS initialized');
        }
        _casInitialized = true;
        _loadAds();
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CAS init exception: $e');
      }
      if (_casInitCompleter != null && !_casInitCompleter!.isCompleted) {
        _casInitCompleter!.complete();
      }
    }
  }

  void _loadAds() {
    if (_cfg.config.appOpen.enabled) {
      _appOpenAd ??= CASAppOpen.createAndLoad(
        autoReload: true,
        onAdLoaded: (ad) {
          _appOpenAdLoaded = true;
          if (kDebugMode) {
            debugPrint('✅ CAS App Open loaded');
          }
          if (_casInitCompleter != null && !_casInitCompleter!.isCompleted) {
            _casInitCompleter!.complete();
          }
          if (!_coldStartAdShown) {
            _tryShowAppOpen();
          }
        },
        onAdFailedToLoad: (ad, error) {
          _appOpenAdLoaded = false;
          if (kDebugMode) {
            debugPrint('❌ CAS App Open failed: ${error.message}');
          }
          if (_casInitCompleter != null && !_casInitCompleter!.isCompleted) {
            _casInitCompleter!.complete();
          }
        },
      );
    } else {
      if (_casInitCompleter != null && !_casInitCompleter!.isCompleted) {
        _casInitCompleter!.complete();
      }
    }

    if (_cfg.config.interstitial.priority1Enabled &&
            _cfg.config.interstitial.priority1 == 'cas' ||
        _cfg.config.interstitial.priority2Enabled &&
            _cfg.config.interstitial.priority2 == 'cas') {
      _casInterstitial ??= CASInterstitial.createAndLoad(
        autoReload: true,
        onAdLoaded: (ad) {
          _interstitialAdLoaded = true;
          if (kDebugMode) {
            debugPrint('✅ CAS Interstitial loaded');
          }
        },
        onAdFailedToLoad: (ad, error) {
          _interstitialAdLoaded = false;
          if (kDebugMode) {
            debugPrint('❌ CAS Interstitial failed: ${error.message}');
          }
        },
      );
    }

    if (_cfg.config.rewarded.priority1Enabled &&
            _cfg.config.rewarded.priority1 == 'cas' ||
        _cfg.config.rewarded.priority2Enabled &&
            _cfg.config.rewarded.priority2 == 'cas') {
      _casRewarded ??= CASRewarded.createAndLoad(
        autoReload: true,
        onAdLoaded: (ad) {
          _rewardedAdLoaded = true;
          if (kDebugMode) {
            debugPrint('✅ CAS Rewarded loaded');
          }
        },
        onAdFailedToLoad: (ad, error) {
          _rewardedAdLoaded = false;
          if (kDebugMode) {
            debugPrint('❌ CAS Rewarded failed: ${error.message}');
          }
        },
      );
    }
  }

  /// Call this after remote config refresh to ensure
  /// CAS ads are loaded when admin enables CAS remotely
  void refreshAdLoad() {
    if (!_casInitialized) return;
    _loadAds();
  }

  /// Called from main.dart on cold start and app resume
  bool _isCooldownActive() {
    if (_lastAppOpenTime == null) return false;
    final elapsed = DateTime.now().difference(_lastAppOpenTime!);
    return elapsed.inHours < _cfg.config.appOpen.cooldownHours;
  }

  void _tryShowAppOpen() {
    if (!_casInitialized) return;
    if (!_cfg.config.appOpen.enabled) return;
    if (_appOpenAd == null) return;
    if (!_appOpenAdLoaded) return;
    if (_isCooldownActive()) {
      if (kDebugMode) {
        debugPrint('ℹ️ App Open cooldown active');
      }
      return;
    }
    final currentRoute = Get.currentRoute;
    if (currentRoute != AppRoutes.main && currentRoute != '/') {
      if (kDebugMode) {
        debugPrint('ℹ️ App Open skipped — user on $currentRoute');
      }
      return;
    }
    _appOpenAdLoaded = false;
    _coldStartAdShown = true;
    _appOpenAd!.onAdShowed = (ad) {
      _lastAppOpenTime = DateTime.now();
      if (kDebugMode) {
        debugPrint('▶️ CAS App Open shown');
      }
    };
    _appOpenAd!.onAdFailedToShow = (ad, error) {
      _appOpenAdLoaded = false;
      _coldStartAdShown = false;
      if (kDebugMode) {
        debugPrint('❌ CAS App Open failed to show: ${error.message}');
      }
    };
    _appOpenAd!.onAdDismissed = (ad) {
      if (kDebugMode) {
        debugPrint('✅ CAS App Open dismissed');
      }
    };
    _appOpenAd!.show();
  }

  Future<void> showAppOpen() async {
    if (!_casInitialized) return;
    if (!_cfg.config.appOpen.enabled) return;
    if (_appOpenAd == null) return;
    if (_isCooldownActive()) {
      if (kDebugMode) {
        debugPrint('ℹ️ App Open cooldown active');
      }
      return;
    }
    _tryShowAppOpen();
  }

  /// Called from AdService waterfall — CAS interstitial fallback
  Future<bool> showInterstitialFallback() async {
    if (!_casInitialized) return false;
    if (_casInterstitial == null) return false;
    if (!_interstitialAdLoaded) {
      if (kDebugMode) {
        debugPrint('ℹ️ CAS Interstitial not ready');
      }
      return false;
    }
    final shown = Completer<bool>();
    _interstitialAdLoaded = false;
    _casInterstitial!.onAdShowed = (ad) {
      if (kDebugMode) {
        debugPrint('▶️ CAS Interstitial shown');
      }
    };
    _casInterstitial!.onAdDismissed = (ad) {
      shown.complete(true);
    };
    _casInterstitial!.onAdFailedToShow = (ad, error) {
      if (kDebugMode) {
        debugPrint('❌ CAS Interstitial failed to show: ${error.message}');
      }
      shown.complete(false);
    };
    _casInterstitial!.show();
    return shown.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
  }

  /// Called from AdService waterfall — CAS rewarded fallback
  Future<bool> showRewardedFallback({
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    if (!_casInitialized) return false;
    if (_casRewarded == null) {
      return false;
    }
    if (!_rewardedAdLoaded) {
      if (kDebugMode) {
        debugPrint('ℹ️ CAS Rewarded not ready');
      }
      return false;
    }
    bool rewardGranted = false;
    _rewardedAdLoaded = false;
    _casRewarded!.onUserEarnedReward = (ad) {
      if (kDebugMode) {
        debugPrint('🎁 CAS Reward earned');
      }
      rewardGranted = true;
      onRewarded();
    };
    _casRewarded!.onAdDismissed = (ad) {
      if (!rewardGranted) onNotAvailable?.call();
    };
    _casRewarded!.onAdFailedToShow = (ad, error) {
      if (kDebugMode) {
        debugPrint('❌ CAS Rewarded failed to show: ${error.message}');
      }
      _rewardedAdLoaded = false;
      onNotAvailable?.call();
    };
    _casRewarded!.show();
    return true;
  }



  @override
  void onClose() {
    _appOpenAd?.dispose();
    _casInterstitial?.dispose();
    _casRewarded?.dispose();
    super.onClose();
  }
}
