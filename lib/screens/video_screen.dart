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

/// Video player screen
///
/// OTT-style: shows thumbnail with play button first.
/// WebView only loads when user taps play — prevents Error 153.
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  WebViewController? _webViewController;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<VideoController>();
  }

  /// Called when user taps the play button on thumbnail
  /// Only then WebView is initialized and loaded
  void _initializePlayer() {
    controller.hasVideoError.value = false; // Reset error on retry
    FirebaseAnalytics.instance.logEvent(
      name: 'video_played',
      parameters: {
        'episode_title': controller.episode.title,
        'episode_number': controller.episode.episodeNumber,
      },
    );
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
          onPageStarted: (String url) {
            controller.isVideoLoading.value = true;
          },
          onPageFinished: (String url) {
            controller.isVideoLoading.value = false;
          },
          onWebResourceError: (WebResourceError error) {
            controller.isVideoLoading.value = false;
            if (error.isForMainFrame == true) {
              debugPrint('Critical WebView error: ${error.description}');
              setState(() {
                _webViewController = null;
                controller.isPlayerInitialized.value = false;
                controller.hasVideoError.value = true;
              });
            }
          },
          // ✅ 11.7 — URL filtering: only allow YouTube embed and base URL
          // Anything else opens in external browser, never inside the WebView
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url == 'about:blank' ||
                url.startsWith('https://www.youtube.com/embed/') ||
                url.startsWith('https://drama-hubs.blogspot.com')) {
              return NavigationDecision.navigate;
            }
            // Open all other URLs externally
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

  Future<bool> _onWillPop() async {
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
    await Share.share(text, subject: episode.title);
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

                  // Video Container
                  _VideoContainer(
                    webViewController: _webViewController,
                    controller: controller,
                    onPlayTapped: _initializePlayer,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Now Playing Banner
                  _NowPlayingBanner(controller: controller),

                  const SizedBox(height: AppSpacing.xl),

                  // Episode Info Card
                  _EpisodeInfoCard(controller: controller),

                  const SizedBox(height: AppSpacing.xl),

                  // Download Section
                  _DownloadSection(controller: controller),

                  const SizedBox(height: AppSpacing.xl),

                  // Telegram CTA
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

/// Video container
///
/// State 1: videoUrl empty → show error
/// State 2: player not initialized → show thumbnail + play button
/// State 3: player initialized → show WebView
class _VideoContainer extends StatelessWidget {
  final WebViewController? webViewController;
  final VideoController controller;
  final VoidCallback onPlayTapped;

  const _VideoContainer({
    required this.webViewController,
    required this.controller,
    required this.onPlayTapped,
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
            // State 1: No video available
            if (controller.episode.videoUrl.isEmpty) {
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

            // State 2: Player not initialized — show thumbnail + play button
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

            // State 3: Player initialized — show WebView
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

/// Thumbnail with play button overlay
/// Shown before user taps play — exactly like Blogger website
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
          // Thumbnail image
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

          // Dark gradient overlay
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

          // Center play button or error indicator
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
                  : Container(
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
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
            ),
          ),

          // Bottom episode title
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

/// Now Playing banner
class _NowPlayingBanner extends StatelessWidget {
  final VideoController controller;

  const _NowPlayingBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Now Playing',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            '${controller.episode.durationMinutes} min',
            style: AppTypography.body.copyWith(color: AppColors.goldAccent),
          ),
        ],
      ),
    );
  }
}

/// Episode info card
class _EpisodeInfoCard extends StatelessWidget {
  final VideoController controller;

  const _EpisodeInfoCard({required this.controller});

  @override
  Widget build(BuildContext context) {
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'EP ${controller.episode.episodeNumber}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  controller.episode.title,
                  style: AppTypography.headlineMedium.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (controller.dramaTitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'From: ${controller.dramaTitle}',
              style: AppTypography.caption.copyWith(color: AppColors.softGrey),
            ),
          ],
        ],
      ),
    );
  }
}

/// Download section
class _DownloadSection extends StatelessWidget {
  final VideoController controller;
  const _DownloadSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Obx(
        () => Column(
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white70),
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
              style:
                  AppTypography.caption.copyWith(color: AppColors.softGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
