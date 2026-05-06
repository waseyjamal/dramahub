import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
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
      debugPrint('🔄 Ad session reset');
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
    Appodeal.setAutoCache(AppodealAdType.Interstitial, true);
    Appodeal.setAutoCache(AppodealAdType.RewardedVideo, true);

    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) =>
          debugPrint('✅ Interstitial loaded'),
      onInterstitialFailedToLoad: () =>
          debugPrint('❌ Interstitial failed to load'),
      onInterstitialShown: () => debugPrint('▶️ Interstitial shown'),
      onInterstitialClosed: () => debugPrint('✅ Interstitial closed'),
      onInterstitialShowFailed: () =>
          debugPrint('❌ Interstitial failed to show'),
      onInterstitialClicked: () => debugPrint('👆 Interstitial clicked'),
      onInterstitialExpired: () => debugPrint('⏰ Interstitial expired'),
    );

    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) =>
          debugPrint('✅ Rewarded loaded'),
      onRewardedVideoFailedToLoad: () =>
          debugPrint('❌ Rewarded failed to load'),
      onRewardedVideoShown: () => debugPrint('▶️ Rewarded shown'),
      onRewardedVideoClosed: (isFinished) =>
          debugPrint('✅ Rewarded closed finished:$isFinished'),
      onRewardedVideoShowFailed: () =>
          debugPrint('❌ Rewarded failed to show'),
      onRewardedVideoClicked: () => debugPrint('👆 Rewarded clicked'),
      onRewardedVideoExpired: () => debugPrint('⏰ Rewarded expired'),
      onRewardedVideoFinished: (amount, reward) {
        debugPrint('🎁 Reward earned: $amount $reward');
      },
    );

    await Appodeal.initialize(
      appKey: _appKey,
      adTypes: [
        AppodealAdType.Interstitial,
        AppodealAdType.RewardedVideo,
      ],
      onInitializationFinished: (errors) {
        if (errors == null || errors.isEmpty) {
          debugPrint('✅ Appodeal initialized successfully');
        } else {
          for (var error in errors) {
            debugPrint('❌ Appodeal init error: ${error.description}');
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

    final canShow = await Appodeal.canShow(AppodealAdType.Interstitial);
    if (!canShow) {
      debugPrint('ℹ️ Interstitial not ready');
      return;
    }

    await Appodeal.show(AppodealAdType.Interstitial);
    _interstitialShownCount++;
    _lastInterstitialTime = DateTime.now();
    debugPrint('✅ Interstitial shown on $screenKey');
  }

  Future<void> showRewardedForScreen(
    String screenKey, {
    required VoidCallback onRewarded,
    VoidCallback? onNotAvailable,
  }) async {
    if (!_cfg.adsEnabled) return;
    if (!_cfg.canShowRewardedOn(screenKey)) {
      onNotAvailable?.call();
      return;
    }

    _checkSessionReset();
    final rewardedConfig = _cfg.config.rewarded;
    if (_rewardedShownCount >= rewardedConfig.maxPerSession) {
      debugPrint('ℹ️ Rewarded max per session reached');
      onNotAvailable?.call();
      return;
    }
    if (_lastRewardedTime != null) {
      final elapsed = DateTime.now().difference(_lastRewardedTime!);
      if (elapsed.inSeconds < rewardedConfig.cooldownSeconds) {
        debugPrint('ℹ️ Rewarded cooldown active');
        onNotAvailable?.call();
        return;
      }
    }

    final canShow = await Appodeal.canShow(AppodealAdType.RewardedVideo);
    if (!canShow) {
      debugPrint('ℹ️ Rewarded not ready');
      onNotAvailable?.call();
      return;
    }

    _rewardGranted = false;
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoFinished: (amount, reward) {
        debugPrint('🎁 Reward earned on $screenKey: $amount $reward');
        _rewardGranted = true;
        onRewarded(); // ← Fire reward immediately here
      },
      onRewardedVideoClosed: (isFinished) {
        if (!_rewardGranted) {
          onNotAvailable?.call();
        }
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
    debugPrint('✅ Rewarded shown on $screenKey');
  }

  // App Open not supported in Appodeal 3.12.0
  // Will be added when supported
  Future<void> showAppOpen() async {
    debugPrint('ℹ️ App Open not supported in current Appodeal version');
    return;
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

