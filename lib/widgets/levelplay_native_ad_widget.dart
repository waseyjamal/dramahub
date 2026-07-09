import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'package:drama_hub/services/ad_config_service.dart';

class LevelPlayNativeAdWidget extends StatefulWidget {
  final String screenKey;
  const LevelPlayNativeAdWidget({super.key, required this.screenKey});

  @override
  State<LevelPlayNativeAdWidget> createState() =>
      _LevelPlayNativeAdWidgetState();
}

class _LevelPlayNativeAdWidgetState extends State<LevelPlayNativeAdWidget>
    with LevelPlayNativeAdListener {
  LevelPlayNativeAd? _nativeAd;

  static final Set<String> _attemptedScreens = {};

  AdConfigService get _cfg => AdConfigService.instance;

  @override
  void initState() {
    super.initState();
    if (_attemptedScreens.contains(widget.screenKey)) return;
    _attemptedScreens.add(widget.screenKey);
    if (_cfg.config.native.isEnabledForScreen(widget.screenKey)) {
      _nativeAd = LevelPlayNativeAd.builder().withListener(this).build();
    }
  }

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    if (mounted) {
      setState(() {
        _nativeAd = nativeAd;
      });
    }
    if (kDebugMode) {
      debugPrint('✅ LevelPlay Native Ad loaded on ${widget.screenKey}');
    }
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, IronSourceError error) {
    if (kDebugMode) {
      debugPrint(
        '❌ LevelPlay Native Ad failed on ${widget.screenKey}: ${error.message}',
      );
    }
  }

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {}

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {}

  @override
  void dispose() {
    _nativeAd?.destroyAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_nativeAd == null) return const SizedBox.shrink();

    return LevelPlayNativeAdView(
      key: GlobalKey(),
      height: 175,
      width: double.infinity,
      nativeAd: _nativeAd,
      onPlatformViewCreated: () {
        _nativeAd?.loadAd();
      },
      templateType: LevelPlayTemplateType.SMALL,
      templateStyle: LevelPlayNativeAdTemplateStyle(
        callToActionStyle: LevelPlayNativeAdElementStyle(
          backgroundColor: Colors.red,
          textColor: Colors.white,
        ),
      ),
    );
  }
}
