import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import 'package:drama_hub/services/ad_config_service.dart';

class YandexBannerAdWidget extends StatefulWidget {
  final String screenKey;
  const YandexBannerAdWidget({super.key, required this.screenKey});

  @override
  State<YandexBannerAdWidget> createState() => _YandexBannerAdWidgetState();
}

class _YandexBannerAdWidgetState extends State<YandexBannerAdWidget> {
  // ── Per-screen banner ad unit IDs
  static const Map<String, String> _adUnitIds = {
    'home_screen': 'R-M-19564249-9',
    'episodes_screen': 'R-M-19564249-10',
    'watchlist_screen': 'R-M-19564249-11',
    'history_screen': 'R-M-19564249-12',
    'upcoming_screen': 'R-M-19564249-13',
    'download_screen': 'R-M-19564249-13',
  };

  static const String _demoBannerAdUnitId = 'demo-banner-yandex';

  BannerAd? _banner;
  bool _adLoaded = false;

  StreamSubscription<BannerAdLoadState>? _loadSubscription;
  StreamSubscription<BannerAdEvent>? _eventSubscription;

  AdConfigService get _cfg => AdConfigService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_cfg.config.adNetworks.yandexEnabled &&
          _cfg.config.native.isEnabledForScreen(widget.screenKey)) {
        _createBanner();
      }
    });
  }

  void _createBanner() {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width.round();

    final adUnitId = kDebugMode
        ? _demoBannerAdUnitId
        : (_adUnitIds[widget.screenKey] ?? '');

    if (adUnitId.isEmpty) return;

    final banner = BannerAd(
      adSize: BannerAdSize.inline(width: screenWidth, maxHeight: 150),
    );

    _loadSubscription = banner.loadStateStream.listen((state) {
      if (state is BannerAdLoadStateLoaded) {
        if (!mounted) {
          banner.destroy();
          return;
        }
        setState(() => _adLoaded = true);
        if (kDebugMode) {
          debugPrint('✅ Yandex Banner loaded on ${widget.screenKey}');
        }
      } else if (state is BannerAdLoadStateError) {
        if (kDebugMode) {
          debugPrint('❌ Yandex Banner failed on ${widget.screenKey}');
          debugPrint('   → error.description : ${state.error.description}');
          debugPrint('   → error.code        : ${state.error.code}');
          debugPrint('   → full toString()   : ${state.error}');
          debugPrint('   → state toString()  : $state');
        }
      }
    });

    _eventSubscription = banner.events.listen((event) {
      if (event is BannerAdClickedEvent) {
        if (kDebugMode) {
          debugPrint('👆 Yandex Banner clicked on ${widget.screenKey}');
        }
      } else if (event is BannerAdImpressionEvent) {
        if (kDebugMode) {
          debugPrint('👁️ Yandex Banner impression on ${widget.screenKey}');
        }
      }
    });

    banner.load(AdRequest(adUnitId: adUnitId));
    _banner = banner;
  }

  @override
  void dispose() {
    _loadSubscription?.cancel();
    _eventSubscription?.cancel();
    _banner?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adLoaded || _banner == null) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 150),
      child: SizedBox(
        width: double.infinity,
        child: AdWidget(bannerAd: _banner!),
      ),
    );
  }
}
