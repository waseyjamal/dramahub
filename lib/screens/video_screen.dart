import 'dart:async';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:drama_hub/services/ad_config_service.dart';
import 'package:drama_hub/services/vast_ad_service.dart';
import 'package:video_player/video_player.dart';
import 'package:drama_hub/widgets/telegram_cta_button.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/video_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/controllers/home_controller.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with WidgetsBindingObserver {
  WebViewController? _webViewController;
  BetterPlayerController? _betterPlayerController;

  // VAST ad state — all Rx so Obx tracks them
  final RxBool _vastPlaying = false.obs;
  final RxBool _vastCompleted = false.obs;
  final RxInt _vastSecondsLeft = 0.obs;
  final RxBool _showSkipButton = false.obs;
  final Rx<VideoPlayerController?> _vastController = Rx<VideoPlayerController?>(
    null,
  );
  final Rx<BetterPlayerController?> _betterPlayerControllerObs =
      Rx<BetterPlayerController?>(null);

  Timer? _vastTimer;
  Timer? _skipTimer;
  bool _isInitializing = false;
  final RxBool _hlsLoading = false.obs;

  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<VideoController>();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vastTimer?.cancel();
    _skipTimer?.cancel();
    _vastController.value?.pause();
    _vastController.value?.dispose();
    _betterPlayerController?.pause();
    _betterPlayerController?.dispose();
    _betterPlayerControllerObs.value = null;
    super.dispose();
  }

  // Pause everything when app goes to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _vastController.value?.pause();
      _betterPlayerController?.pause();
    }
  }

  Future<void> _initializePlayer() async {
    // Prevent double tap
    if (_isInitializing) return;
    if (controller.isPlayerInitialized.value) return;
    _isInitializing = true;

    try {
      controller.hasVideoError.value = false;

      FirebaseAnalytics.instance.logEvent(
        name: 'video_played',
        parameters: {
          'episode_title': controller.episode.title,
          'episode_number': controller.episode.episodeNumber,
        },
      );

      if (controller.isCustomPlayer.value) {
        if (controller.streamUrl.value.isEmpty) return;

        final vastService = VastAdService.instance;
        if (vastService.canShowAd()) {
          final result = await vastService.fetchAd();
          if (result.success) {
            // Mark player as initialized BEFORE playing ad
            // so UI switches from thumbnail to ad overlay
            controller.isPlayerInitialized.value = true;
            await _playVastAd(result);
            vastService.recordAdShown();
            return;
          }
        }
        _startHlsPlayer();
      } else {
        if (controller.episode.videoId.isEmpty) return;
        final videoId = controller.episode.videoId;
        final html =
            '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
* { margin:0; padding:0; background:#000; }
iframe { width:100%; height:100%; border:none; }
body { width:100vw; height:100vh; overflow:hidden; }
</style>
</head>
<body>
<iframe
  src="https://www.youtube.com/embed/$videoId?autoplay=1&rel=0&modestbranding=1&enablejsapi=1&playsinline=1"
  allow="autoplay; encrypted-media; fullscreen"
  allowfullscreen>
</iframe>
</body>
</html>
''';
        final webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) => controller.isVideoLoading.value = true,
              onPageFinished: (_) => controller.isVideoLoading.value = false,
              onWebResourceError: (WebResourceError error) {
                controller.isVideoLoading.value = false;
                if (error.isForMainFrame == true) {
                  setState(() {
                    _webViewController = null;
                    controller.isPlayerInitialized.value = false;
                    controller.hasVideoError.value = true;
                    _isInitializing = false;
                  });
                }
              },
              onNavigationRequest: (NavigationRequest request) {
                final url = request.url;
                if (url == 'about:blank' ||
                    url.startsWith('https://www.youtube.com/embed/') ||
                    url.startsWith('https://drama-hubs.blogspot.com')) {
                  return NavigationDecision.navigate;
                }
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              },
            ),
          )
          ..loadHtmlString(html, baseUrl: 'https://drama-hubs.blogspot.com');
        setState(() {
          _webViewController = webController;
          controller.isPlayerInitialized.value = true;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _playVastAd(VastAdResult result) async {
    final mp4Url = result.mp4Url;
    final skipSeconds = AdConfigService.instance.config.vast.skipAfterSeconds;

    // Initialize video player
    final vc = VideoPlayerController.networkUrl(Uri.parse(mp4Url));
    try {
      await vc.initialize();
    } catch (e) {
      // Ad failed to load — go straight to HLS
      vc.dispose();
      _startHlsPlayer();
      return;
    }

    // Only assign after successful init
    _vastController.value = vc;
    _vastSecondsLeft.value = skipSeconds;
    _vastPlaying.value = true;
    _vastCompleted.value = false;
    _showSkipButton.value = false;

    await vc.play();
    VastAdService.instance.fireImpression(result.impressionUrl);

    // Countdown timer — counts down skip seconds
    _vastTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final vc = _vastController.value;
      if (vc != null && vc.value.isInitialized) {
        final remaining = (vc.value.duration - vc.value.position).inSeconds;
        _vastSecondsLeft.value = remaining.clamp(0, 999);
      }
    });

    // Show skip button after skipAfterSeconds
    _skipTimer = Timer(Duration(seconds: skipSeconds), () {
      if (!mounted) return;
      _showSkipButton.value = true;
    });

    // Auto finish when ad ends
    vc.addListener(() {
      if (!mounted) return;
      final val = vc.value;
      if (val.duration.inMilliseconds > 0 &&
          val.position >= val.duration &&
          !_vastCompleted.value) {
        _finishVastAd();
      }
    });
  }

  void _skipVastAd() {
    _vastTimer?.cancel();
    _skipTimer?.cancel();
    final vc = _vastController.value;
    _vastController.value = null;
    _vastPlaying.value = false;
    _showSkipButton.value = false;
    vc?.pause();
    vc?.dispose();
    _startHlsPlayer();
  }

  void _finishVastAd() {
    if (_vastCompleted.value) return;
    _vastCompleted.value = true;
    _vastTimer?.cancel();
    _skipTimer?.cancel();
    final vc = _vastController.value;
    _vastController.value = null;
    _vastPlaying.value = false;
    _showSkipButton.value = false;
    vc?.pause();
    vc?.dispose();
    _startHlsPlayer();
  }

  void _startHlsPlayer() {
    // Dispose previous instance
    _betterPlayerController?.pause();
    _betterPlayerController?.dispose();
    _betterPlayerController = null;
    _betterPlayerControllerObs.value = null;

    // Show loading while HLS initializes
    _hlsLoading.value = true;

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      controller.streamUrl.value,
      videoFormat: BetterPlayerVideoFormat.hls,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 10000,
        maxBufferMs: 30000,
        bufferForPlaybackMs: 2500,
        bufferForPlaybackAfterRebufferMs: 5000,
      ),
    );
    final config = BetterPlayerConfiguration(
      autoPlay: true,
      looping: false,
      fullScreenByDefault: false,
      allowedScreenSleep: false,
      fit: BoxFit.contain,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        enablePlayPause: true,
        enableSkips: true,
        enableFullscreen: true,
        enableProgressBar: true,
        enablePlaybackSpeed: true,
        enableAudioTracks: true,
        enableQualities: true,
        forwardSkipTimeInMilliseconds: 10000,
        backwardSkipTimeInMilliseconds: 10000,
        progressBarPlayedColor: Color(0xFFE50914),
        progressBarHandleColor: Color(0xFFE50914),
        loadingColor: Color(0xFFE50914),
        overflowMenuIconsColor: Colors.white,
        iconsColor: Colors.white,
      ),
      eventListener: (event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          controller.isVideoLoading.value = false;
          _hlsLoading.value = false;
        }
        if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          controller.hasVideoError.value = true;
          _hlsLoading.value = false;
        }
      },
    );

    _betterPlayerController = BetterPlayerController(config);
    _betterPlayerController!.setupDataSource(dataSource);
    _betterPlayerControllerObs.value = _betterPlayerController;

    if (!controller.isPlayerInitialized.value) {
      controller.isPlayerInitialized.value = true;
    }
  }

  Future<bool> _onWillPop() async {
    // Pause everything before leaving
    _vastController.value?.pause();
    _betterPlayerController?.pause();
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      return false;
    }
    return true;
  }

  Future<void> _shareEpisode() async {
    HapticFeedback.lightImpact();
    final episode = controller.episode;
    final text =
        '🎬 Watch ${episode.title} on Drama Hub!\n'
        'Episode ${episode.episodeNumber} is now available.\n\n'
        '📲 Download the App:\n'
        'https://play.google.com/store/apps/details?id=com.dramahub.drama_hub\n\n'
        '📢 Join our Telegram for latest episodes:\n'
        'https://t.me/araftahindisub';
    await SharePlus.instance.share(
      ShareParams(text: text, subject: episode.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Get.back();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(controller.episode.title),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _shareEpisode,
              tooltip: 'Share Episode',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  _VideoContainer(
                    webViewController: _webViewController,
                    betterPlayerControllerObs: _betterPlayerControllerObs,
                    hlsLoadingObs: _hlsLoading,
                    controller: controller,
                    onPlayTapped: _initializePlayer,
                    vastPlayingObs: _vastPlaying,
                    vastControllerObs: _vastController,
                    vastSecondsLeftObs: _vastSecondsLeft,
                    showSkipButtonObs: _showSkipButton,
                    onSkipVast: _skipVastAd,
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  _DownloadSection(controller: controller),
                  const SizedBox(height: AppSpacing.xl),
                  /*
                  // Next Episode Card
                  if (controller.nextEpisode != null)
                    _NextEpisodeCard(controller: controller),
                  if (controller.nextEpisode != null)
                    const SizedBox(height: AppSpacing.xl),
                  */

                  // Episode List
                  if (controller.allEpisodes.isNotEmpty)
                    _EpisodeListSection(controller: controller),
                  if (controller.allEpisodes.isNotEmpty)
                    const SizedBox(height: AppSpacing.xl),

                  // Watch Progress
                  if (controller.drama != null)
                    _WatchProgressSection(controller: controller),
                  if (controller.drama != null)
                    const SizedBox(height: AppSpacing.xl),

                  // Drama Info
                  if (controller.drama != null)
                    _DramaInfoCard(controller: controller),
                  if (controller.drama != null)
                    const SizedBox(height: AppSpacing.xl),

                  // Similar Dramas
                  if (controller.similarDramas.isNotEmpty)
                    _SimilarDramasSection(controller: controller),
                  if (controller.similarDramas.isNotEmpty)
                    const SizedBox(height: AppSpacing.xl),

                  const TelegramCTAButton(),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoContainer extends StatelessWidget {
  final WebViewController? webViewController;
  final VideoController controller;
  final VoidCallback onPlayTapped;
  final Rx<BetterPlayerController?> betterPlayerControllerObs;
  final RxBool hlsLoadingObs;
  final RxBool vastPlayingObs;
  final Rx<VideoPlayerController?> vastControllerObs;
  final RxInt vastSecondsLeftObs;
  final RxBool showSkipButtonObs;
  final VoidCallback? onSkipVast;

  const _VideoContainer({
    required this.webViewController,
    required this.controller,
    required this.onPlayTapped,
    required this.betterPlayerControllerObs,
    required this.hlsLoadingObs,
    required this.vastPlayingObs,
    required this.vastControllerObs,
    required this.vastSecondsLeftObs,
    required this.showSkipButtonObs,
    this.onSkipVast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Obx(() {
            final isCustom = controller.isCustomPlayer.value;
            final videoUrl = isCustom
                ? controller.streamUrl.value
                : controller.episode.videoUrl;

            // State 1: No video
            if (videoUrl.isEmpty && !controller.isPlayerInitialized.value) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white54, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Video Unavailable',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            }

            // State 2: Not initialized — thumbnail
            if (!controller.isPlayerInitialized.value) {
              return _ThumbnailPlayer(
                thumbnailUrl: controller.dramaBanner.isNotEmpty
                    ? controller.dramaBanner
                    : controller.episode.thumbnailImage,
                episodeTitle: controller.episode.title,
                onPlayTapped: onPlayTapped,
                controller: controller,
              );
            }

            // State 3: Initialized
            if (isCustom) {
              return _VastOrHlsPlayer(
                vastPlayingObs: vastPlayingObs,
                vastSecondsLeftObs: vastSecondsLeftObs,
                showSkipButtonObs: showSkipButtonObs,
                vastControllerObs: vastControllerObs,
                betterPlayerControllerObs: betterPlayerControllerObs,
                hlsLoadingObs: hlsLoadingObs,
                onSkipVast: onSkipVast,
              );
            }

            return Stack(
              children: [
                WebViewWidget(controller: webViewController!),
                if (controller.isVideoLoading.value)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _VastOrHlsPlayer extends StatelessWidget {
  final RxBool vastPlayingObs;
  final RxInt vastSecondsLeftObs;
  final RxBool showSkipButtonObs;
  final Rx<VideoPlayerController?> vastControllerObs;
  final Rx<BetterPlayerController?> betterPlayerControllerObs;
  final RxBool hlsLoadingObs;
  final VoidCallback? onSkipVast;

  const _VastOrHlsPlayer({
    required this.vastPlayingObs,
    required this.vastSecondsLeftObs,
    required this.showSkipButtonObs,
    required this.vastControllerObs,
    required this.betterPlayerControllerObs,
    required this.hlsLoadingObs,
    this.onSkipVast,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final vc = vastControllerObs.value;
      final bpc = betterPlayerControllerObs.value;
      final isHlsLoading = hlsLoadingObs.value;

      // Show VAST ad
      if (vastPlayingObs.value && vc != null) {
        return _VastAdOverlay(
          vastController: vc,
          secondsLeft: vastSecondsLeftObs.value,
          showSkipButton: showSkipButtonObs.value,
          onSkip: onSkipVast ?? () {},
        );
      }

      // HLS loading — smooth transition spinner
      if (isHlsLoading || bpc == null) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE50914),
              strokeWidth: 2,
            ),
          ),
        );
      }

      // HLS playing
      return BetterPlayer(controller: bpc);
    });
  }
}

class _ThumbnailPlayer extends StatelessWidget {
  final String thumbnailUrl;
  final String episodeTitle;
  final VoidCallback onPlayTapped;
  final VideoController controller;

  const _ThumbnailPlayer({
    required this.thumbnailUrl,
    required this.episodeTitle,
    required this.onPlayTapped,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onPlayTapped();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  memCacheHeight: 225,
                  fadeInDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black87,
                    child: const Icon(
                      Icons.movie_outlined,
                      color: Colors.white30,
                      size: 48,
                    ),
                  ),
                )
              : Container(color: Colors.black87),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
                stops: [0.5, 1.0],
              ),
            ),
          ),
          Obx(
            () => Center(
              child: controller.hasVideoError.value
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap to retry',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    )
                  : _AnimatedPlayButton(onTap: () {
                      HapticFeedback.heavyImpact();
                      onPlayTapped();
                    }),
            ),
          ),
          Positioned(
            bottom: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Text(
              episodeTitle,
              style: AppTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [const Shadow(color: Colors.black, blurRadius: 8)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}



class _DownloadSection extends StatelessWidget {
  final VideoController controller;
  const _DownloadSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isCustomPlayer.value) return const SizedBox.shrink();
      return Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryDark,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Download Episode', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: controller.isDownloadLoading.value
                  ? null
                  : controller.goToDownload,
              icon: controller.isDownloadLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                controller.isDownloadLoading.value
                    ? 'Loading...'
                    : 'Free Download',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Download opens in external browser.',
              style: AppTypography.caption.copyWith(color: AppColors.softGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    });
  }
}

class _VastAdOverlay extends StatelessWidget {
  final VideoPlayerController vastController;
  final int secondsLeft;
  final bool showSkipButton;
  final VoidCallback onSkip;

  const _VastAdOverlay({
    required this.vastController,
    required this.secondsLeft,
    required this.showSkipButton,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: vastController.value.aspectRatio,
          child: VideoPlayer(vastController),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'AD • ${secondsLeft}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (showSkipButton)
          Positioned(
            bottom: 40,
            right: 10,
            child: GestureDetector(
              onTap: onSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white54),
                ),
                child: const Text(
                  'Skip Ad ›',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            vastController,
            allowScrubbing: false,
            colors: const VideoProgressColors(
              playedColor: Color(0xFFE50914),
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
      ],
    );
  }
}



// ─────────────────────────────────────────────────────────────────
// EPISODE LIST SECTION
// ─────────────────────────────────────────────────────────────────
class _EpisodeListSection extends StatelessWidget {
  final VideoController controller;
  const _EpisodeListSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('All Episodes', style: AppTypography.title),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.allEpisodes.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final ep = controller.allEpisodes[index];
              final isCurrent =
                  ep.episodeNumber == controller.episode.episodeNumber;
              return GestureDetector(
                onTap: isCurrent
                    ? null
                    : () {
                        final adService = Get.find<AdService>();
                        final targetEp = ep;
                        final dramaTitle = controller.dramaTitle;
                        final dramaBanner = controller.dramaBanner;

                        void navigate() {
                          Get.delete<VideoController>(force: true);
                          Get.offAndToNamed(
                            AppRoutes.video,
                            arguments: {
                              'episode': targetEp,
                              'dramaTitle': dramaTitle,
                              'dramaBanner': dramaBanner,
                            },
                          );
                        }

                        adService.showRewardedForScreen(
                          'episodes_screen',
                          onRewarded: navigate,
                          onNotAvailable: navigate,
                        );
                      },
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.primaryRed
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: isCurrent
                          ? AppColors.primaryRed
                          : AppColors.softGrey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'EP',
                        style: AppTypography.caption.copyWith(
                          color: isCurrent
                              ? Colors.white70
                              : AppColors.softGrey,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${ep.episodeNumber}',
                        style: AppTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// WATCH PROGRESS SECTION
// ─────────────────────────────────────────────────────────────────
class _WatchProgressSection extends StatelessWidget {
  final VideoController controller;
  const _WatchProgressSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final drama = controller.drama!;
    final current = controller.episode.episodeNumber;
    final total = drama.totalEpisodes > 0
        ? drama.totalEpisodes
        : controller.allEpisodes.length;
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Progress', style: AppTypography.title),
              Text(
                'EP $current of $total',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.softGrey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryRed,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            progress >= 1.0
                ? '🎉 You completed this drama!'
                : '${((progress) * 100).toStringAsFixed(0)}% watched',
            style: AppTypography.caption.copyWith(color: AppColors.softGrey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// DRAMA INFO CARD
// ─────────────────────────────────────────────────────────────────
class _DramaInfoCard extends StatelessWidget {
  final VideoController controller;
  const _DramaInfoCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final drama = controller.drama!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              if (drama.posterImage.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: CachedNetworkImage(
                    imageUrl: drama.posterImage,
                    width: 70,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(
                      width: 70,
                      height: 100,
                      color: Colors.black54,
                    ),
                  ),
                ),
              if (drama.posterImage.isNotEmpty)
                const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drama.title,
                      style: AppTypography.headlineMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.goldAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          drama.rating.toStringAsFixed(1),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.goldAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.softGrey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          drama.genre,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.softGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${drama.totalEpisodes} Episodes',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softGrey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${drama.releaseYear}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.softGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (drama.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              drama.description,
              style: AppTypography.caption.copyWith(
                color: AppColors.softGrey,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SIMILAR DRAMAS SECTION
// ─────────────────────────────────────────────────────────────────
class _SimilarDramasSection extends StatelessWidget {
  final VideoController controller;
  const _SimilarDramasSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('More Dramas', style: AppTypography.title),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.similarDramas.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final drama = controller.similarDramas[index];
              return GestureDetector(
                onTap: () {
                  Get.find<HomeController>().goToEpisodesSkipAd(drama);
                },
                child: SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        child: CachedNetworkImage(
                          imageUrl: drama.posterImage,
                          width: 110,
                          height: 140,
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) => Container(
                            width: 110,
                            height: 140,
                            color: Colors.black54,
                            child: const Icon(
                              Icons.movie_outlined,
                              color: Colors.white30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        drama.title,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
class _AnimatedPlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedPlayButton({required this.onTap});

  @override
  State<_AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<_AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animController.forward(),
      onTapUp: (_) {
        _animController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _animController,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}
