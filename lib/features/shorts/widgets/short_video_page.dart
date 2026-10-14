import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/features/shorts/controllers/shorts_playback_controller.dart';
import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/services/shorts_local_store.dart';
import 'package:drama_hub/features/shorts/services/shorts_repository.dart';
import 'package:drama_hub/features/shorts/widgets/short_progress_bar.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/utils/app_snackbar.dart';

/// One full-screen page of the vertical player.
class ShortVideoPage extends StatefulWidget {
  const ShortVideoPage({
    super.key,
    required this.index,
    required this.controller,
    required this.onEpisodesTap,
    this.onOpenSeries,
  });

  final int index;
  final ShortsPlaybackController controller;
  final VoidCallback onEpisodesTap;

  /// Feed mode: open the series screen at the given episode.
  final void Function(int episodeNumber)? onOpenSeries;

  @override
  State<ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<ShortVideoPage> {
  final List<_Heart> _hearts = [];
  int _heartId = 0;
  Offset _lastDoubleTap = Offset.zero;

  ShortsPlaybackController get _c => widget.controller;
  ShortItem get _item => _c.items[widget.index];
  bool get _isFeed => _c.mode == ShortsMode.feed;

  void _onDoubleTap() {
    HapticFeedback.lightImpact();
    final store = ShortsLocalStore.instance;
    if (!store.isSaved(_item.series.id)) {
      store.toggleSaved(shortsSummaryOf(_item.series));
    }
    setState(() => _hearts.add(_Heart(_heartId++, _lastDoubleTap)));
  }

  void _share() {
    final url = AppConfigService.instance.config.websiteUrl;
    SharePlus.instance.share(
      ShareParams(
        text:
            'Watch "${_item.series.title}" Episode ${_item.episode.number} on Drama Hub 🎬\n$url',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return ColoredBox(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _c.pool,
        builder: (context, _) {
          final player = _c.playerAt(widget.index);
          final locked = _c.isLocked(widget.index);
          final loadError = _c.pool.errorAt(widget.index);
          return Stack(
            fit: StackFit.expand,
            children: [
              _Poster(
                url: item.episode.thumbUrl.isNotEmpty
                    ? item.episode.thumbUrl
                    : item.series.posterUrl,
                blur: locked,
              ),
              if (player != null && !locked) _VideoLayer(player: player),
              if (!locked)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _c.togglePause,
                  onDoubleTapDown: (d) => _lastDoubleTap = d.localPosition,
                  onDoubleTap: _onDoubleTap,
                  onLongPressStart: (_) {
                    HapticFeedback.selectionClick();
                    _c.setBoost(true);
                  },
                  onLongPressEnd: (_) => _c.setBoost(false),
                  onLongPressCancel: () => _c.setBoost(false),
                ),
              const _BottomShade(),
              if (locked)
                _LockedLayer(controller: _c, index: widget.index)
              else if (loadError != null)
                _ErrorLayer(onRetry: () => _c.retry(widget.index))
              else
                _StatusLayer(controller: _c, index: widget.index, player: player),
              _BoostChip(controller: _c),
              ..._hearts.map(
                (h) => _HeartBurst(
                  key: ValueKey(h.id),
                  at: h.at,
                  onDone: () => setState(() => _hearts.remove(h)),
                ),
              ),
              _InfoAndRail(
                item: item,
                isFeed: _isFeed,
                controller: _c,
                onEpisodesTap: widget.onEpisodesTap,
                onShare: _share,
                onOpenSeries: widget.onOpenSeries,
              ),
              if (_isFeed && !locked)
                _EndCard(
                  controller: _c,
                  index: widget.index,
                  onNext: widget.onOpenSeries,
                ),
              if (player != null && !locked)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _c.current,
                    builder: (_, cur, _) => ShortProgressBar(
                      controller: player,
                      active: cur == widget.index,
                      onSeek: _c.seekTo,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Layers ─────────────────────────────────────────────────────────────────

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.blur});
  final String url;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.expand();
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      placeholder: (_, _) => const SizedBox.expand(),
      errorWidget: (_, _, _) => const SizedBox.expand(),
    );
    if (!blur) return image;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: image,
    );
  }
}

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.player});
  final VideoPlayerController player;

  @override
  Widget build(BuildContext context) {
    final size = player.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.expand();
    // Vertical video fills the screen; landscape video is letterboxed.
    final vertical = size.width / size.height < 0.8;
    return RepaintBoundary(
      child: FittedBox(
        fit: vertical ? BoxFit.cover : BoxFit.contain,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(player),
        ),
      ),
    );
  }
}

class _BottomShade extends StatelessWidget {
  const _BottomShade();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.18, 0.6, 1],
            colors: [
              Color(0x66000000),
              Colors.transparent,
              Colors.transparent,
              Color(0xCC000000),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spinner while loading/buffering and the play icon while paused.
class _StatusLayer extends StatelessWidget {
  const _StatusLayer({
    required this.controller,
    required this.index,
    required this.player,
  });
  final ShortsPlaybackController controller;
  final int index;
  final VideoPlayerController? player;

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) return const IgnorePointer(child: Center(child: _Spinner()));
    return IgnorePointer(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: p,
        builder: (_, v, _) {
          if (v.hasError) return const Center(child: _Spinner());
          return ValueListenableBuilder<bool>(
            valueListenable: controller.userPaused,
            builder: (_, paused, _) {
              if (paused) {
                return const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 84,
                    color: Colors.white70,
                  ),
                );
              }
              if (v.isBuffering) {
                return const Center(child: _DelayedSpinner());
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 34,
    height: 34,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
  );
}

/// Short buffering hiccups (<400 ms) don't flash a spinner.
class _DelayedSpinner extends StatefulWidget {
  const _DelayedSpinner();

  @override
  State<_DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<_DelayedSpinner> {
  late final Future<void> _delay = Future<void>.delayed(
    const Duration(milliseconds: 400),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _delay,
    builder: (_, snap) => snap.connectionState == ConnectionState.done
        ? const _Spinner()
        : const SizedBox.shrink(),
  );
}

class _ErrorLayer extends StatelessWidget {
  const _ErrorLayer({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 40),
          const SizedBox(height: 10),
          const Text(
            "Couldn't play this video",
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _LockedLayer extends StatefulWidget {
  const _LockedLayer({required this.controller, required this.index});
  final ShortsPlaybackController controller;
  final int index;

  @override
  State<_LockedLayer> createState() => _LockedLayerState();
}

class _LockedLayerState extends State<_LockedLayer> {
  bool _busy = false;

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final ok = await widget.controller.unlock(widget.index);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppSnackbar.info(
        'No ad available',
        'Please try again in a moment.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.controller.items[widget.index];
    final count = ShortsRepository.instance.config.value.ads.unlockEpisodesPerAd;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.goldAccent, size: 46),
            const SizedBox(height: 12),
            Text(
              'Episode ${item.episode.number} is locked',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count > 1
                  ? 'Watch a short ad to unlock the next $count episodes'
                  : 'Watch a short ad to unlock this episode',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _busy ? null : _unlock,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Watch ad to unlock'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoostChip extends StatelessWidget {
  const _BoostChip({required this.controller});
  final ShortsPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.boosted,
      builder: (_, on, _) => IgnorePointer(
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 56),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '2x',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Info + right rail ──────────────────────────────────────────────────────

class _InfoAndRail extends StatelessWidget {
  const _InfoAndRail({
    required this.item,
    required this.isFeed,
    required this.controller,
    required this.onEpisodesTap,
    required this.onShare,
    required this.onOpenSeries,
  });

  final ShortItem item;
  final bool isFeed;
  final ShortsPlaybackController controller;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShare;
  final void Function(int)? onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final store = ShortsLocalStore.instance;
    final series = item.series;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    series.totalEpisodes > 0
                        ? 'EP ${item.episode.number} · ${series.totalEpisodes} episodes'
                        : 'EP ${item.episode.number}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (series.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ExpandableText(series.description),
                  ],
                  if (isFeed && onOpenSeries != null) ...[
                    const SizedBox(height: 10),
                    _WatchSeriesPill(
                      total: series.totalEpisodes,
                      onTap: () => onOpenSeries!(item.episode.number),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  final saved = store.isSaved(series.id);
                  return _RailButton(
                    icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: saved ? AppColors.primaryRed : Colors.white,
                    label: saved ? 'Saved' : 'Save',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      store.toggleSaved(shortsSummaryOf(series));
                    },
                  );
                }),
                _RailButton(
                  icon: Icons.video_library_rounded,
                  label: 'Episodes',
                  onTap: onEpisodesTap,
                ),
                _RailButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: onShare,
                ),
                Obx(
                  () => _RailButton(
                    icon: store.muted.value
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    label: store.muted.value ? 'Muted' : 'Sound',
                    onTap: controller.toggleMute,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 31, shadows: const [Shadow(blurRadius: 8)]),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                shadows: [Shadow(blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchSeriesPill extends StatelessWidget {
  const _WatchSeriesPill({required this.total, required this.onTap});
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              total > 0 ? 'Watch full series · $total EP' : 'Watch full series',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topLeft,
        child: Text(
          widget.text,
          maxLines: _expanded ? 8 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.35,
            shadows: [Shadow(blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

// ── End-of-episode card (feed mode) ────────────────────────────────────────

class _EndCard extends StatelessWidget {
  const _EndCard({
    required this.controller,
    required this.index,
    required this.onNext,
  });
  final ShortsPlaybackController controller;
  final int index;
  final void Function(int)? onNext;

  @override
  Widget build(BuildContext context) {
    final item = controller.items[index];
    final hasNext =
        onNext != null &&
        (item.series.totalEpisodes == 0 ||
            item.episode.number < item.series.totalEpisodes);
    return ValueListenableBuilder<int>(
      valueListenable: controller.current,
      builder: (_, cur, _) => ValueListenableBuilder<bool>(
        valueListenable: controller.ended,
        builder: (_, ended, _) {
          if (!ended || cur != index) return const SizedBox.shrink();
          return ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasNext)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => onNext!(item.episode.number + 1),
                      icon: const Icon(Icons.skip_next_rounded),
                      label: Text('Watch Episode ${item.episode.number + 1}'),
                    ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: controller.replay,
                    icon: const Icon(Icons.replay_rounded, color: Colors.white70),
                    label: const Text(
                      'Replay',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Double-tap heart ───────────────────────────────────────────────────────

class _Heart {
  _Heart(this.id, this.at);
  final int id;
  final Offset at;
}

class _HeartBurst extends StatefulWidget {
  const _HeartBurst({super.key, required this.at, required this.onDone});
  final Offset at;
  final VoidCallback onDone;

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return Positioned(
      left: widget.at.dx - size / 2,
      top: widget.at.dy - size / 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, child) {
            final t = _a.value;
            final scale = t < 0.25
                ? Curves.easeOutBack.transform(t / 0.25) * 1.15
                : 1.15 - (t - 0.25) * 0.2;
            final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -40 * t),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: const Icon(
            Icons.favorite_rounded,
            color: AppColors.primaryRed,
            size: size,
            shadows: [Shadow(blurRadius: 16)],
          ),
        ),
      ),
    );
  }
}
