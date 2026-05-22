import 'package:flutter/foundation.dart';
import 'package:clever_ads_solutions/clever_ads_solutions.dart';
import 'package:flutter/material.dart';
import 'package:drama_hub/services/ad_config_service.dart';
import 'package:drama_hub/ui_system/colors.dart';

class CasNativeAdWidget extends StatefulWidget {
  final String screenKey;

  const CasNativeAdWidget({super.key, required this.screenKey});

  @override
  State<CasNativeAdWidget> createState() => _CasNativeAdWidgetState();
}

class _CasNativeAdWidgetState extends State<CasNativeAdWidget> {
  AdViewInstance? _nativeAd;
  bool _adLoaded = false;

  // Tracks which screens have already attempted a load this session
  // Static so it survives Obx rebuilds that recreate widget instances
  static final Set<String> _attemptedScreens = {};

  AdConfigService get _cfg => AdConfigService.instance;

  @override
  void initState() {
    super.initState();
    if (_attemptedScreens.contains(widget.screenKey)) return;
    _attemptedScreens.add(widget.screenKey);
    if (_cfg.config.native.isEnabledForScreen(widget.screenKey)) {
      _loadAd();
    }
  }

  void _loadAd() {
    CASNativeContent.load(
      templateStyle: NativeTemplateStyle(
        backgroundColor: AppColors.cardBackground,
        primaryColor: AppColors.primaryRed,
        primaryTextColor: AppColors.white,
        headlineTextColor: AppColors.white,
        headlineFontStyle: NativeTemplateFontStyle.bold,
        secondaryTextColor: AppColors.softGrey,
        secondaryFontStyle: null,
      ),
      onAdLoaded: (AdViewInstance ad) {
        if (mounted) {
          setState(() {
            _nativeAd = ad;
            _adLoaded = true;
          });
        }
        if (kDebugMode) { debugPrint('✅ CAS Native Ad loaded on ${widget.screenKey}'); }
      },
      onAdFailedToLoad: (AdInstance ad, AdError error) {
        if (kDebugMode) {
          debugPrint(
            '❌ CAS Native Ad failed on ${widget.screenKey}: ${error.message}',
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CASWidget(
            ad: _nativeAd!,
            width: constraints.maxWidth,
            height: 100,
          ),
        );
      },
    );
  }
}
