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

class _LevelPlayNativeAdWidgetState extends State<LevelPlayNativeAdWidget> {
  static const String _nativeAdUnitId = 'l3zy61iv0ebvaaua';

  LevelPlayNativeAd? _nativeAd;
  bool _adLoaded = false;

  AdConfigService get _cfg => AdConfigService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_cfg.config.adNetworks.levelplayEnabled &&
          _cfg.config.native.isEnabledForScreen(widget.screenKey)) {
        _loadAd();
      }
    });
  }

  void _loadAd() {
    final ad = LevelPlayNativeAd.builder()
        .withAdUnitId(_nativeAdUnitId)
        .withListener(_NativeAdListener(
          onAdLoaded: (ad, adInfo) {
            if (!mounted) {
              ad.destroy();
              return;
            }
            setState(() => _adLoaded = true);
            if (kDebugMode) {
              debugPrint('✅ LevelPlay Native loaded on ${widget.screenKey}');
            }
          },
          onAdLoadFailed: (ad, error) {
            if (kDebugMode) {
              debugPrint(
                '❌ LevelPlay Native failed on ${widget.screenKey}: $error',
              );
            }
          },
        ))
        .build();
    ad.loadAd();
    _nativeAd = ad;
  }

  @override
  void dispose() {
    _nativeAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adLoaded || _nativeAd == null) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 150),
      child: SizedBox(
        width: double.infinity,
        child: LevelPlayNativeAdView(
          ad: _nativeAd!,
          templateType: LevelPlayTemplateType.SMALL,
        ),
      ),
    );
  }
}

// ── Native Ad Listener ────────────────────────────────────────────────────────

class _NativeAdListener with LevelPlayNativeAdListener {
  final void Function(LevelPlayNativeAd ad, LevelPlayAdInfo adInfo) onAdLoaded;
  final void Function(LevelPlayNativeAd ad, LevelPlayAdError error)
  onAdLoadFailed;

  _NativeAdListener({required this.onAdLoaded, required this.onAdLoadFailed});

  @override
  void onAdLoaded(LevelPlayNativeAd ad, LevelPlayAdInfo adInfo) =>
      onAdLoaded(ad, adInfo);

  @override
  void onAdLoadFailed(LevelPlayNativeAd ad, LevelPlayAdError error) =>
      onAdLoadFailed(ad, error);

  @override
  void onAdClicked(LevelPlayNativeAd ad, LevelPlayAdInfo adInfo) {}

  @override
  void onAdImpression(LevelPlayNativeAd ad, LevelPlayAdInfo adInfo) {
    if (kDebugMode) debugPrint('👁️ LevelPlay Native impression');
  }
}
