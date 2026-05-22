import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:drama_hub/services/cas_service.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'ad_config_service.dart';

class AdService extends GetxService {
  static AdService get instance => Get.find<AdService>();

  static const String _appKey =
      '6a73151827ab64c724ed4211304766dbc57b48d249c6b217';

  int _interstitialShownCount = 0;
  DateTime? _lastInterstitialTime;
  DateTime _sessionStartTime = DateTime.now();
  bool _rewardGranted = false;
  int _rewardedShownCount = 0;
  DateTime? _lastRewardedTime;

  AdConfigService get _cfg => AdConfigService.instance;

  void _checkSessionReset() {
    final diff = DateTime.now().difference(_sessionStartTime);
    if (diff.inHours >= 4) {
      _interstitialShownCount = 0;
      _sessionStartTime = DateTime.now();
      if (kDebugMode) { debugPrint('🔄 Ad session reset'); }
    }
  }

  void resetSession() {
    _interstitialShownCount = 0;
    _lastInterstitialTime = null;
    _rewardedShownCount = 0;
    _lastRewardedTime = null;
    _sessionStartTime = DateTime.now();
  }


  Future<void> _initAppodeal() async {
    Appodeal.setTesting(!kReleaseMode);
    Appodeal.setLogLevel(
      kReleaseMode ? Appodeal.LogLevelNone : Appodeal.LogLevelVerbose,
    );
    // Appodeal.setAutoCache(AppodealAdType.Interstitial, true); // DISABLED — 0.5% fill rate
    Appodeal.setAutoCache(AppodealAdType.RewardedVideo, true);

    // DISABLED — Appodeal Interstitial commented out (0.5% fill rate)
    // Appodeal.setInterstitialCallbacks(
    //   onInterstitialLoaded: (isPrecache) { if (kDebugMode) { debugPrint('✅ Interstitial loaded'); } },
    //   onInterstitialFailedToLoad: () { if (kDebugMode) { debugPrint('❌ Interstitial failed to load'); } },
    //   onInterstitialShown: () { if (kDebugMode) { debugPrint('▶️ Interstitial shown'); } },
    //   onInterstitialClosed: () { if (kDebugMode) { debugPrint('✅ Interstitial closed'); } },
    //   onInterstitialShowFailed: () { if (kDebugMode) { debugPrint('❌ Interstitial failed to show'); } },
    //   onInterstitialClicked: () { if (kDebugMode) { debugPrint('👆 Interstitial clicked'); } },
    //   onInterstitialExpired: () { if (kDebugMode) { debugPrint('⏰ Interstitial expired'); } },
    // );

    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) { if (kDebugMode) { debugPrint('✅ Rewarded loaded'); } },
      onRewardedVideoFailedToLoad: () { if (kDebugMode) { debugPrint('❌ Rewarded failed to load'); } },
      onRewardedVideoShown: () { if (kDebugMode) { debugPrint('▶️ Rewarded shown'); } },
      onRewardedVideoClosed: (isFinished) { if (kDebugMode) { debugPrint('✅ Rewarded closed finished:$isFinished'); } },
      onRewardedVideoShowFailed: () { if (kDebugMode) { debugPrint('❌ Rewarded failed to show'); } },
      onRewardedVideoClicked: () { if (kDebugMode) { debugPrint('👆 Rewarded clicked'); } },
      onRewardedVideoExpired: () { if (kDebugMode) { debugPrint('⏰ Rewarded expired'); } },
      onRewardedVideoFinished: (amount, reward) {
        if (kDebugMode) { debugPrint('🎁 Reward earned: $amount $reward'); }
      },
    );

    await Appodeal.initialize(
      appKey: _appKey,
      adTypes: [
        // AppodealAdType.Interstitial, // DISABLED — 0.5% fill rate
        AppodealAdType.RewardedVideo,
      ],
      onInitializationFinished: (errors) {
        if (errors == null || errors.isEmpty) {
          if (kDebugMode) { debugPrint('✅ Appodeal initialized successfully'); }
        } else {
          for (var error in errors) {
            if (kDebugMode) { debugPrint('❌ Appodeal init error: ${error.description}'); }
          }
        }
      },
    );
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

    // Priority 1
    if (config.priority1Enabled) {
      if (config.priority1 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.Interstitial);
        if (canShow) {
          await Appodeal.show(AppodealAdType.Interstitial);
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Interstitial shown via Appodeal on $screenKey');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ Appodeal Interstitial not ready, trying fallback');
        }
      } else if (config.priority1 == 'cas' &&
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
        if (kDebugMode) {
          debugPrint('ℹ️ CAS Interstitial not ready, trying fallback');
        }
      }
    }

    // Priority 2
    if (config.priority2Enabled) {
      if (config.priority2 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.Interstitial);
        if (canShow) {
          await Appodeal.show(AppodealAdType.Interstitial);
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
          if (kDebugMode) {
            debugPrint(
                '✅ Interstitial shown via Appodeal fallback on $screenKey');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ Appodeal Interstitial fallback not ready');
        }
      } else if (config.priority2 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        final shown = await CasService.instance.showInterstitialFallback();
        if (shown) {
          _interstitialShownCount++;
          _lastInterstitialTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Interstitial shown via CAS fallback on $screenKey');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ CAS Interstitial fallback not ready');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('ℹ️ No Interstitial available on $screenKey');
    }
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
    final rewardedConfig = _cfg.config.rewarded;
    if (_rewardedShownCount >= rewardedConfig.maxPerSession) {
      if (kDebugMode) {
        debugPrint('ℹ️ Rewarded max per session reached');
      }
      onNotAvailable?.call();
      return;
    }
    if (_lastRewardedTime != null) {
      final elapsed = DateTime.now().difference(_lastRewardedTime!);
      if (elapsed.inSeconds < rewardedConfig.cooldownSeconds) {
        if (kDebugMode) {
          debugPrint('ℹ️ Rewarded cooldown active');
        }
        onNotAvailable?.call();
        return;
      }
    }

    // Priority 1
    if (rewardedConfig.priority1Enabled) {
      if (rewardedConfig.priority1 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.RewardedVideo);
        if (canShow) {
          _rewardGranted = false;
          Appodeal.setRewardedVideoCallbacks(
            onRewardedVideoFinished: (amount, reward) {
              if (kDebugMode) {
                debugPrint('🎁 Reward earned on $screenKey: $amount $reward');
              }
              _rewardGranted = true;
              onRewarded();
            },
            onRewardedVideoClosed: (isFinished) {
              if (!_rewardGranted) onNotAvailable?.call();
            },
            onRewardedVideoShowFailed: () => onNotAvailable?.call(),
            onRewardedVideoLoaded: (isPrecache) {},
            onRewardedVideoFailedToLoad: () {},
            onRewardedVideoShown: () {},
            onRewardedVideoClicked: () {},
            onRewardedVideoExpired: () {},
          );
          await Appodeal.show(AppodealAdType.RewardedVideo);
          _rewardedShownCount++;
          _lastRewardedTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Rewarded shown via Appodeal on $screenKey');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ Appodeal Rewarded not ready, trying fallback');
        }
      } else if (rewardedConfig.priority1 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        final shown = await CasService.instance.showRewardedFallback(
          onRewarded: onRewarded,
          onNotAvailable: onNotAvailable,
        );
        if (shown) {
          _rewardedShownCount++;
          _lastRewardedTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Rewarded shown via CAS on $screenKey');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ CAS Rewarded not ready, trying fallback');
        }
      }
    }

    // Priority 2
    if (rewardedConfig.priority2Enabled) {
      if (rewardedConfig.priority2 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.RewardedVideo);
        if (canShow) {
          _rewardGranted = false;
          Appodeal.setRewardedVideoCallbacks(
            onRewardedVideoFinished: (amount, reward) {
              if (kDebugMode) {
                debugPrint('🎁 Reward earned on $screenKey: $amount $reward');
              }
              _rewardGranted = true;
              onRewarded();
            },
            onRewardedVideoClosed: (isFinished) {
              if (!_rewardGranted) onNotAvailable?.call();
            },
            onRewardedVideoShowFailed: () => onNotAvailable?.call(),
            onRewardedVideoLoaded: (isPrecache) {},
            onRewardedVideoFailedToLoad: () {},
            onRewardedVideoShown: () {},
            onRewardedVideoClicked: () {},
            onRewardedVideoExpired: () {},
          );
          await Appodeal.show(AppodealAdType.RewardedVideo);
          _rewardedShownCount++;
          _lastRewardedTime = DateTime.now();
          if (kDebugMode) {
            debugPrint(
                '✅ Rewarded shown via Appodeal fallback on $screenKey');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ Appodeal Rewarded fallback not ready');
        }
      } else if (rewardedConfig.priority2 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        final shown = await CasService.instance.showRewardedFallback(
          onRewarded: onRewarded,
          onNotAvailable: onNotAvailable,
        );
        if (shown) {
          _rewardedShownCount++;
          _lastRewardedTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Rewarded shown via CAS fallback on $screenKey');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ CAS Rewarded fallback not ready');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('ℹ️ No Rewarded available on $screenKey');
    }
    onNotAvailable?.call();
  }

  Future<void> showAppOpen() async {
    if (!_cfg.adsEnabled) return;
    if (!_cfg.appOpenEnabled) return;
    if (_cfg.config.adNetworks.casEnabled) {
      await CasService.instance.showAppOpen();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _sessionStartTime = DateTime.now();
    if (_cfg.adsEnabled) {
      _initAppodeal();
    }
  }
}

