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
    final placementName = _cfg.config.native.adUnitId;
    var builder = LevelPlayNativeAd.builder().withListener(this);
    if (placementName.isNotEmpty) builder = builder.withPlacementName(placementName);
    _nativeAd = builder.build();
    _nativeAd!.loadAd();
  }

  @override
  void dispose() {
    _nativeAd?.destroyAd();
    super.dispose();
  }

  // ── LevelPlayNativeAdListener ─────────────────────────────────────────────

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    if (!mounted) {
      nativeAd.destroyAd();
      return;
    }
    setState(() => _adLoaded = true);
    if (kDebugMode) debugPrint('✅ LevelPlay Native loaded on ${widget.screenKey}');
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, IronSourceError error) {
    if (kDebugMode) {
      debugPrint('❌ LevelPlay Native failed on ${widget.screenKey}: $error');
    }
  }

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {}

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    if (kDebugMode) debugPrint('👁️ LevelPlay Native impression');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_adLoaded || _nativeAd == null) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 150),
      child: SizedBox(
        width: double.infinity,
        child: LevelPlayNativeAdView(
          nativeAd: _nativeAd,
          templateType: LevelPlayTemplateType.SMALL,
        ),
      ),
    );
  }
}
