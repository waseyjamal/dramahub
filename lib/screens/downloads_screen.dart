import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:drama_hub/models/download_model.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/services/ad_config_service.dart';
import 'package:drama_hub/services/download_service.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/utils/app_snackbar.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DownloadService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        centerTitle: true,
      ),
      body: Obx(() {
        final active = service.activeDownloads.values.toList();
        final completed = service.completedDownloads;

        if (active.isEmpty && completed.isEmpty) {
          return _EmptyState();
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ✅ Storage summary
            _StorageSummary(service: service),
            const SizedBox(height: AppSpacing.lg),

            // ✅ Active downloads
            if (active.isNotEmpty) ...[
              Text('Downloading', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              ...active.map((d) => _ActiveDownloadCard(
                    download: d,
                    service: service,
                  )),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ✅ Completed downloads
            if (completed.isNotEmpty) ...[
              Text('Downloaded Episodes', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              ...completed.map((ep) => _CompletedEpisodeCard(
                    episode: ep,
                    service: service,
                  )),
            ],
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// EMPTY STATE (completely untouched)
// ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 80,
            color: AppColors.softGrey.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No Downloads Yet', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Download episodes to watch\nanytime, even offline!',
            style: AppTypography.body.copyWith(color: AppColors.softGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STORAGE SUMMARY (completely untouched)
// ─────────────────────────────────────────────────────────────────
class _StorageSummary extends StatelessWidget {
  final DownloadService service;
  const _StorageSummary({required this.service});

  @override
  Widget build(BuildContext context) {
    final totalBytes = service.completedDownloads
        .fold<int>(0, (sum, e) => sum + e.fileSizeBytes);
    final totalMb = totalBytes / 1024 / 1024;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded,
              color: AppColors.primaryRed, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${service.completedDownloads.length} episodes • ${totalMb.toStringAsFixed(0)} MB used',
            style: AppTypography.caption.copyWith(color: AppColors.softGrey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ACTIVE DOWNLOAD CARD
// Changes: added MB progress text below percentage
// Everything else untouched
// ─────────────────────────────────────────────────────────────────
class _ActiveDownloadCard extends StatelessWidget {
  final ActiveDownload download;
  final DownloadService service;

  const _ActiveDownloadCard({
    required this.download,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final isPaused = download.status == DownloadStatus.paused;
    final isFailed = download.status == DownloadStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.dramaTitle,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.softGrey),
                    ),
                    Text(
                      'Episode ${download.episodeNumber}',
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFailed
                      ? Colors.red.withValues(alpha: 0.15)
                      : isPaused
                          ? Colors.orange.withValues(alpha: 0.15)
                          : AppColors.primaryRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFailed
                      ? 'Failed'
                      : isPaused
                          ? 'Paused'
                          : 'Downloading',
                  style: AppTypography.caption.copyWith(
                    color: isFailed
                        ? Colors.red
                        : isPaused
                            ? Colors.orange
                            : AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (!isFailed) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Obx(() => LinearProgressIndicator(
                    value: service
                            .activeDownloads[download.episodeId]
                            ?.progress ??
                        download.progress,
                    backgroundColor:
                        AppColors.softGrey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPaused ? Colors.orange : AppColors.primaryRed,
                    ),
                    minHeight: 6,
                  )),
            ),
            const SizedBox(height: AppSpacing.sm),
            // ✅ FIX — shows both percentage AND MB progress
            Obx(() {
              final active =
                  service.activeDownloads[download.episodeId];
              final p = active?.progress ?? download.progress;
              final mbText = active?.mbProgressText ?? '';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPaused
                        ? 'Paused — ${(p * 100).toStringAsFixed(0)}%'
                        : '${(p * 100).toStringAsFixed(0)}%',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.softGrey),
                  ),
                  if (mbText.isNotEmpty)
                    Text(
                      mbText,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.softGrey),
                    ),
                ],
              );
            }),
          ],

          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              if (!isFailed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (isPaused) {
                        service.resumeDownload(download.episodeId);
                      } else {
                        service.pauseDownload(download.episodeId);
                      }
                    },
                    icon: Icon(
                      isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 18,
                    ),
                    label: Text(isPaused ? 'Resume' : 'Pause'),
                  ),
                ),
              if (!isFailed) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      service.cancelDownload(download.episodeId),
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    // ✅ FIX — horizontal padding so text is not cramped
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.lg,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// COMPLETED EPISODE CARD
// Changes:
//   - Full card tappable via GestureDetector (plays episode)
//   - Play IconButton removed from trailing — only delete icon remains
//   - Thumbnail changed from 60x60 to 60x80 (portrait ratio)
//   - Loading indicator shown on tap while getPlaybackPath() runs
// Everything else untouched
// ─────────────────────────────────────────────────────────────────
class _CompletedEpisodeCard extends StatefulWidget {
  final DownloadedEpisode episode;
  final DownloadService service;

  const _CompletedEpisodeCard({
    required this.episode,
    required this.service,
  });

  @override
  State<_CompletedEpisodeCard> createState() => _CompletedEpisodeCardState();
}

class _CompletedEpisodeCardState extends State<_CompletedEpisodeCard> {
  // ✅ Loading state — shows indicator immediately on tap
  bool _isLoading = false;

  Future<void> _play() async {
    if (_isLoading) return;

    final offlineCfg = AdConfigService.instance.offlineAds;
    final isMature = widget.episode.isAdMature(offlineCfg.maturityMinutes);

    if (isMature) {
      await AdService.instance.showOfflineAd(
        onComplete: () => _navigateToPlayer(),
      );
    } else {
      await _navigateToPlayer();
    }
  }

  Future<void> _navigateToPlayer() async {
    if (!mounted) return;

    // ✅ Show loading indicator immediately — user gets instant feedback
    setState(() => _isLoading = true);

    final playbackPath =
        await widget.service.getPlaybackPath(widget.episode.episodeId);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (playbackPath == null) {
      AppSnackbar.error(
        'Playback Failed',
        'File corrupted or missing. Please re-download.',
      );
      return;
    }

    Get.to(
      () => OfflinePlayerScreen(
        episode: widget.episode,
        filePath: playbackPath,
      ),
      transition: Transition.downToUp,
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.secondaryDark,
        title: Text('Delete Download', style: AppTypography.title),
        content: Text(
          'Delete "${widget.episode.displayName}"?\nThis cannot be undone.',
          style: AppTypography.body.copyWith(color: AppColors.softGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.service.deleteDownload(widget.episode.episodeId);
    }
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _play,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.cardShadow,
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail — flush to left edge, rounded left corners only
             ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: widget.episode.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.episode.thumbnailUrl,
                      width: 65,
                      height: 85,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: 65,
                        height: 85,
                        color: AppColors.secondaryDark,
                        child: const Icon(Icons.movie_outlined,
                            color: Colors.white30),
                      ),
                    )
                  : Container(
                      width: 65,
                      height: 85,
                      color: AppColors.secondaryDark,
                      child: const Icon(Icons.movie_outlined,
                          color: Colors.white30),
                    ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Episode info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.episode.dramaTitle,
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Episode ${widget.episode.episodeNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.episode.sizeText} • ${_formatDate(widget.episode.downloadedAt)}',
                      style: TextStyle(
                        color: AppColors.softGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right side — loading spinner OR delete icon
            // IconButton absorbs its own tap — does NOT trigger card play
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryRed,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white24,
                ),
                onPressed: _delete,
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// OFFLINE PLAYER SCREEN (completely untouched)
// ─────────────────────────────────────────────────────────────────
class OfflinePlayerScreen extends StatefulWidget {
  final DownloadedEpisode episode;
  final String filePath;

  const OfflinePlayerScreen({
    required this.episode,
    required this.filePath,
  });

  @override
  State<OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<OfflinePlayerScreen>
    with WidgetsBindingObserver {
  BetterPlayerController? _playerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
  }

  void _initPlayer() {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      widget.filePath,
      videoFormat: BetterPlayerVideoFormat.other,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 5000,
        maxBufferMs: 30000,
        bufferForPlaybackMs: 2500,
        bufferForPlaybackAfterRebufferMs: 5000,
      ),
    );

    final config = BetterPlayerConfiguration(
      autoPlay: true,
      looping: false,
      fit: BoxFit.contain,
      autoDetectFullscreenAspectRatio: true,
      autoDetectFullscreenDeviceOrientation: true,
      deviceOrientationsOnFullScreen: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: const [
        DeviceOrientation.portraitUp,
      ],
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        enablePlayPause: true,
        enableSkips: true,
        enableFullscreen: true,
        enableProgressBar: true,
        enablePlaybackSpeed: true,
        forwardSkipTimeInMilliseconds: 10000,
        backwardSkipTimeInMilliseconds: 10000,
        progressBarPlayedColor: Color(0xFFE50914),
        progressBarHandleColor: Color(0xFFE50914),
        loadingColor: Color(0xFFE50914),
        iconsColor: Colors.white,
        controlBarColor: Colors.transparent,
      ),
    );

    _playerController = BetterPlayerController(config);
    _playerController!.setupDataSource(dataSource);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _playerController?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerController?.pause();
    _playerController?.dispose();
    // ✅ Clean up temp fallback file for this episode only
    DownloadService.instance.cleanupTempFile(widget.episode.episodeId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.episode.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _playerController != null
                  ? BetterPlayer(controller: _playerController!)
                  : const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFE50914))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.offline_bolt_rounded,
                      color: Colors.green, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Playing offline • ${widget.episode.sizeText}',
                    style: AppTypography.caption
                        .copyWith(color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}