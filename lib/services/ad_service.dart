import 'dart:async';
import 'package:drama_hub/models/ad_config_model.dart';
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
      onRewardedVideoLoaded: (isPrecache) {
        if (kDebugMode) {
          debugPrint('✅ Rewarded loaded');
        }
      },
      onRewardedVideoFailedToLoad: () {
        if (kDebugMode) {
          debugPrint('❌ Rewarded failed to load');
        }
      },
      onRewardedVideoShown: () {
        if (kDebugMode) {
          debugPrint('▶️ Rewarded shown');
        }
      },
      onRewardedVideoClosed: (isFinished) {
        if (kDebugMode) {
          debugPrint('✅ Rewarded closed finished:$isFinished');
        }
      },
      onRewardedVideoShowFailed: () {
        if (kDebugMode) {
          debugPrint('❌ Rewarded failed to show');
        }
      },
      onRewardedVideoClicked: () {
        if (kDebugMode) {
          debugPrint('👆 Rewarded clicked');
        }
      },
      onRewardedVideoExpired: () {
        if (kDebugMode) {
          debugPrint('⏰ Rewarded expired');
        }
      },
      onRewardedVideoFinished: (amount, reward) {
        if (kDebugMode) {
          debugPrint('🎁 Reward earned: $amount $reward');
        }
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
          if (kDebugMode) {
            debugPrint('✅ Appodeal initialized successfully');
          }
        } else {
          for (var error in errors) {
            if (kDebugMode) {
              debugPrint('❌ Appodeal init error: ${error.description}');
            }
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
              '✅ Interstitial shown via Appodeal fallback on $screenKey',
            );
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
          bool rewardGranted = false;
          Appodeal.setRewardedVideoCallbacks(
            onRewardedVideoFinished: (amount, reward) {
              if (kDebugMode) {
                debugPrint('🎁 Reward earned on $screenKey: $amount $reward');
              }
              rewardGranted = true;
              onRewarded();
            },
            onRewardedVideoClosed: (isFinished) {
              if (!rewardGranted) onNotAvailable?.call();
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
          bool rewardGranted = false;
          Appodeal.setRewardedVideoCallbacks(
            onRewardedVideoFinished: (amount, reward) {
              if (kDebugMode) {
                debugPrint('🎁 Reward earned on $screenKey: $amount $reward');
              }
              rewardGranted = true;
              onRewarded();
            },
            onRewardedVideoClosed: (isFinished) {
              if (!rewardGranted) onNotAvailable?.call();
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
            debugPrint('✅ Rewarded shown via Appodeal fallback on $screenKey');
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
      if (kDebugMode) {
        debugPrint('ℹ️ Download rewarded max per session reached');
      }
      onNotAvailable?.call();
      return;
    }

    if (_lastDownloadTime != null) {
      final elapsed = DateTime.now().difference(_lastDownloadTime!);
      if (elapsed.inSeconds < downloadConfig.cooldownSeconds) {
        if (kDebugMode) {
          debugPrint('ℹ️ Download rewarded cooldown active');
        }
        onNotAvailable?.call();
        return;
      }
    }

    // Priority 1
    if (downloadConfig.priority1Enabled) {
      if (downloadConfig.priority1 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.RewardedVideo);
        if (canShow) {
          bool rewardGranted = false;
          Appodeal.setRewardedVideoCallbacks(
            onRewardedVideoFinished: (amount, reward) {
              if (kDebugMode) {
                debugPrint(
                  '🎁 Download reward earned via Appodeal: $amount $reward',
                );
              }
              rewardGranted = true;
              onRewarded();
            },
            onRewardedVideoClosed: (isFinished) {
              if (!rewardGranted) onNotAvailable?.call();
            },
            onRewardedVideoShowFailed: () => onNotAvailable?.call(),
            onRewardedVideoLoaded: (isPrecache) {},
            onRewardedVideoFailedToLoad: () {},
            onRewardedVideoShown: () {},
            onRewardedVideoClicked: () {},
            onRewardedVideoExpired: () {},
          );
          await Appodeal.show(AppodealAdType.RewardedVideo);
          _downloadShownCount++;
          _lastDownloadTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Download rewarded shown via Appodeal');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ Appodeal not ready for download, trying fallback');
        }
      } else if (downloadConfig.priority1 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        final shown = await CasService.instance.showRewardedFallback(
          onRewarded: onRewarded,
          onNotAvailable: onNotAvailable,
        );
        if (shown) {
          _downloadShownCount++;
          _lastDownloadTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Download rewarded shown via CAS');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ CAS not ready for download, trying fallback');
        }
      }
    }

    // Priority 2
    if (downloadConfig.priority2Enabled) {
      if (downloadConfig.priority2 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.RewardedVideo);
        if (canShow) {
          bool rewardGranted = false;
          Appodeal.setRewardedVideoCallbacks(
            onRewardedVideoFinished: (amount, reward) {
              if (kDebugMode) {
                debugPrint(
                  '🎁 Download reward earned via Appodeal fallback: $amount $reward',
                );
              }
              rewardGranted = true;
              onRewarded();
            },
            onRewardedVideoClosed: (isFinished) {
              if (!rewardGranted) onNotAvailable?.call();
            },
            onRewardedVideoShowFailed: () => onNotAvailable?.call(),
            onRewardedVideoLoaded: (isPrecache) {},
            onRewardedVideoFailedToLoad: () {},
            onRewardedVideoShown: () {},
            onRewardedVideoClicked: () {},
            onRewardedVideoExpired: () {},
          );
          await Appodeal.show(AppodealAdType.RewardedVideo);
          _downloadShownCount++;
          _lastDownloadTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Download rewarded shown via Appodeal fallback');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ Appodeal fallback not ready for download');
        }
      } else if (downloadConfig.priority2 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        final shown = await CasService.instance.showRewardedFallback(
          onRewarded: onRewarded,
          onNotAvailable: onNotAvailable,
        );
        if (shown) {
          _downloadShownCount++;
          _lastDownloadTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('✅ Download rewarded shown via CAS fallback');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('ℹ️ CAS fallback not ready for download');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('ℹ️ No rewarded available for download');
    }
    onNotAvailable?.call();
  }

  /// Shows interstitial or rewarded ad for offline episode playback.
  /// Completely separate from all other ad systems.
  /// Returns true if ad was shown, false if skipped.
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

    // ✅ Check session cool period
    if (_lastOfflineAdTime != null) {
      final elapsed = DateTime.now().difference(_lastOfflineAdTime!);
      if (elapsed.inMinutes < offlineCfg.sessionCoolMinutes) {
        if (kDebugMode) {
          debugPrint('ℹ️ Offline ad session cool active');
        }
        onComplete();
        return;
      }
    }

    // ✅ Check max per session
    if (_offlineAdShownCount >= offlineCfg.maxPerSession) {
      if (kDebugMode) {
        debugPrint('ℹ️ Offline ad max per session reached');
      }
      onComplete();
      return;
    }

    // ✅ Route to correct ad type
    if (offlineCfg.adType == 'rewarded') {
      await _showOfflineRewarded(
        offlineCfg: offlineCfg,
        onComplete: onComplete,
      );
    } else {
      await _showOfflineInterstitial(
        offlineCfg: offlineCfg,
        onComplete: onComplete,
      );
    }
  }

  Future<void> _showOfflineInterstitial({
    required OfflineAdConfig offlineCfg,
    required VoidCallback onComplete,
  }) async {
    // Priority 1
    if (offlineCfg.priority1Enabled) {
      if (offlineCfg.priority1 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.Interstitial);
        if (canShow) {
          await Appodeal.show(AppodealAdType.Interstitial);
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline interstitial via Appodeal');
          onComplete();
          return;
        }
      } else if (offlineCfg.priority1 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        final shown = await CasService.instance.showInterstitialFallback();
        if (shown) {
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline interstitial via CAS');
          onComplete();
          return;
        }
      }
    }

    // Priority 2
    if (offlineCfg.priority2Enabled) {
      if (offlineCfg.priority2 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final canShow = await Appodeal.canShow(AppodealAdType.Interstitial);
        if (canShow) {
          await Appodeal.show(AppodealAdType.Interstitial);
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline interstitial via Appodeal P2');
          onComplete();
          return;
        }
      } else if (offlineCfg.priority2 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        final shown = await CasService.instance.showInterstitialFallback();
        if (shown) {
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline interstitial via CAS P2');
          onComplete();
          return;
        }
      }
    }

    if (kDebugMode) debugPrint('ℹ️ No offline interstitial available');
    onComplete();
  }

  Future<void> _showOfflineRewarded({
    required OfflineAdConfig offlineCfg,
    required VoidCallback onComplete,
  }) async {
    bool rewardGranted = false;

    Future<bool> tryAppodeal() async {
      final canShow = await Appodeal.canShow(AppodealAdType.RewardedVideo);
      if (!canShow) return false;
      final completer = Completer<bool>();
      Appodeal.setRewardedVideoCallbacks(
        onRewardedVideoFinished: (amount, reward) {
          rewardGranted = true;
        },
        onRewardedVideoClosed: (isFinished) {
          if (!completer.isCompleted) completer.complete(rewardGranted);
        },
        onRewardedVideoShowFailed: () {
          if (!completer.isCompleted) completer.complete(false);
        },
        onRewardedVideoLoaded: (_) {},
        onRewardedVideoFailedToLoad: () {},
        onRewardedVideoShown: () {},
        onRewardedVideoClicked: () {},
        onRewardedVideoExpired: () {},
      );
      await Appodeal.show(AppodealAdType.RewardedVideo);
      return completer.future;
    }

    // Priority 1
    if (offlineCfg.priority1Enabled) {
      if (offlineCfg.priority1 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final shown = await tryAppodeal();
        if (shown) {
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline rewarded via Appodeal');
          onComplete();
          return;
        }
      } else if (offlineCfg.priority1 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        bool casShown = false;
        final shown = await CasService.instance.showRewardedFallback(
          onRewarded: () => casShown = true,
          onNotAvailable: () {},
        );
        if (shown && casShown) {
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline rewarded via CAS');
          onComplete();
          return;
        }
      }
    }

    // Priority 2
    if (offlineCfg.priority2Enabled) {
      if (offlineCfg.priority2 == 'appodeal' &&
          _cfg.config.adNetworks.appodealEnabled) {
        final shown = await tryAppodeal();
        if (shown) {
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline rewarded via Appodeal P2');
          onComplete();
          return;
        }
      } else if (offlineCfg.priority2 == 'cas' &&
          _cfg.config.adNetworks.casEnabled) {
        bool casShown = false;
        final shown = await CasService.instance.showRewardedFallback(
          onRewarded: () => casShown = true,
          onNotAvailable: () {},
        );
        if (shown && casShown) {
          _offlineAdShownCount++;
          _lastOfflineAdTime = DateTime.now();
          if (kDebugMode) debugPrint('✅ Offline rewarded via CAS P2');
          onComplete();
          return;
        }
      }
    }

    if (kDebugMode) debugPrint('ℹ️ No offline rewarded available');
    // Rewarded not available → play directly, never block user
    onComplete();
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
