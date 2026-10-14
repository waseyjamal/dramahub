import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:drama_hub/features/shorts/controllers/shorts_playback_controller.dart';
import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/services/shorts_feed_ranker.dart';
import 'package:drama_hub/features/shorts/services/shorts_local_store.dart';
import 'package:drama_hub/features/shorts/services/shorts_repository.dart';
import 'package:drama_hub/features/shorts/shorts_routes.dart';
import 'package:drama_hub/features/shorts/widgets/shorts_discover_view.dart';
import 'package:drama_hub/features/shorts/widgets/shorts_player_view.dart';
import 'package:drama_hub/features/shorts/widgets/shorts_state_views.dart';

enum _FeedState { idle, loading, ready, empty, error }

/// The Shorts tab. Nothing loads until the tab is first opened, and all
/// video decoders are released while the tab is hidden, so the rest of
/// the app is never slowed down by it.
class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({super.key, required this.active});

  /// True while the Shorts tab is the selected bottom tab.
  final ValueListenable<bool> active;

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  final ShortsPlaybackController _ctrl = ShortsPlaybackController(
    mode: ShortsMode.feed,
  );
  final PageController _page = PageController();
  _FeedState _state = _FeedState.idle;

  /// Full ranked feed; the player gets it [_pageSize] at a time.
  List<ShortItem> _ranked = const [];
  static const int _pageSize = 20;

  /// Discover page showing (players are released while it is).
  bool _discover = false;
  bool _discoverBuilt = false;

  void _setDiscover(bool value) {
    if (value == _discover) return;
    setState(() {
      _discover = value;
      if (value) _discoverBuilt = true;
    });
    if (!widget.active.value) return;
    if (value) {
      _ctrl.setVisible(false);
      _ctrl.releasePlayers();
    } else {
      _ctrl.restorePlayers();
      _ctrl.setVisible(true);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.active.addListener(_onActiveChanged);
    _ctrl.current.addListener(_maybeLoadMore);
    _onActiveChanged();
  }

  bool get _hasMore => _ctrl.items.length < _ranked.length;

  /// Appends the next page when the user is 5 videos from the end.
  void _maybeLoadMore() {
    if (!_hasMore || _ctrl.current.value < _ctrl.items.length - 5) return;
    final from = _ctrl.items.length;
    _ctrl.appendItems(_ranked.sublist(
      from,
      (from + _pageSize).clamp(0, _ranked.length),
    ));
    if (!_hasMore) setState(() {}); // shows the "all caught up" page
  }

  void _onActiveChanged() {
    final active = widget.active.value;
    if (active) {
      if (_state == _FeedState.idle) _load();
      if (_discover) return; // players stay released until For You
      _ctrl.restorePlayers();
      _ctrl.setVisible(true);
    } else {
      _ctrl.setVisible(false);
      _ctrl.releasePlayers();
    }
  }

  /// [silent] keeps the current videos on screen (pull-to-refresh).
  Future<void> _load({bool force = false, bool silent = false}) async {
    if (!silent) setState(() => _state = _FeedState.loading);
    try {
      await ShortsRepository.instance.init();
      final entries = await ShortsRepository.instance.loadFeed(
        forceRefresh: force,
      );
      if (!mounted) return;
      final store = ShortsLocalStore.instance;
      await store.ensureLoaded();
      final items = ShortsFeedRanker.rank(
        entries.map((e) => ShortItem(e.series, e.episode)).toList(),
        idOf: (i) => i.series.id,
        seen: store.seenIds,
        started: {
          for (final e in entries)
            if (store.maxWatched(e.series.id) > 0) e.series.id,
        },
        seed: DateTime.now().microsecondsSinceEpoch,
      );
      _ranked = items;
      if (items.isEmpty) {
        setState(() => _state = _FeedState.empty);
        return;
      }
      if (_page.hasClients) _page.jumpToPage(0);
      _ctrl.setAtEndPage(false);
      _ctrl.setItems(items.take(_pageSize).toList());
      if (!widget.active.value || _discover) _ctrl.releasePlayers();
      setState(() => _state = _FeedState.ready);
    } catch (_) {
      // A failed refresh keeps the videos already on screen.
      if (mounted && !silent) setState(() => _state = _FeedState.error);
    }
  }

  /// Frees this feed's decoders while another player screen is on top.
  Future<void> _pushReleasing(Future<void> Function() push) async {
    _ctrl.releasePlayers();
    await push();
    if (mounted && widget.active.value && !_discover) _ctrl.restorePlayers();
  }

  void _openSeries(String seriesId, int episode) =>
      _pushReleasing(() => ShortsRoutes.openSeries(seriesId, episode: episode));

  @override
  void dispose() {
    widget.active.removeListener(_onActiveChanged);
    _ctrl.current.removeListener(_maybeLoadMore);
    _ctrl.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + _TabSwitcher.height;
    return PopScope(
      // Back on Discover returns to the player instead of leaving the app.
      canPop: !_discover,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _discover) _setDiscover(false);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Feed stays mounted (keeps its position); hidden on Discover.
              Positioned.fill(
                child: Offstage(offstage: _discover, child: _body()),
              ),
              if (_discoverBuilt)
                Positioned.fill(
                  child: Offstage(
                    offstage: !_discover,
                    child: ShortsDiscoverView(
                      topPadding: topInset,
                      onOpenSeries: (id, ep) =>
                          ShortsRoutes.openSeries(id, episode: ep),
                      onSeeMyList: () async {
                        await Get.toNamed(ShortsRoutes.myList);
                      },
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TabSwitcher(
                  discover: _discover,
                  onChanged: _setDiscover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case _FeedState.idle:
      case _FeedState.loading:
        return const ShortsLoadingView();
      case _FeedState.empty:
        return ShortsMessageView(
          icon: Icons.movie_filter_rounded,
          title: 'New dramas coming soon',
          message: 'Check back shortly for fresh episodes.',
          onRetry: () => _load(force: true),
        );
      case _FeedState.error:
        return ShortsMessageView(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load Shorts",
          message: 'Check your connection and try again.',
          onRetry: () => _load(force: true),
        );
      case _FeedState.ready:
        // Pull down on the first video → fresh order (like TikTok).
        return RefreshIndicator(
          edgeOffset:
              MediaQuery.paddingOf(context).top + _TabSwitcher.height,
          onRefresh: () => _load(force: true, silent: true),
          child: ShortsPlayerView(
            controller: _ctrl,
            pageController: _page,
            onEpisodesTap: (i) {
              final item = _ctrl.items[i];
              _openSeries(item.series.id, item.episode.number);
            },
            onOpenSeries: (i, ep) =>
                _openSeries(_ctrl.items[i].series.id, ep),
            endPage: _hasMore
                ? null
                : _CaughtUpPage(
                    onStartOver: () => _load(force: true, silent: true),
                    onDiscover: () => _setDiscover(true),
                  ),
            onEndPageVisible: _ctrl.setAtEndPage,
          ),
        );
    }
  }
}

/// Shown after the last video of the feed.
class _CaughtUpPage extends StatelessWidget {
  const _CaughtUpPage({required this.onStartOver, required this.onDiscover});
  final VoidCallback onStartOver;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                "You're all caught up",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find more dramas in Discover, or watch the feed again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: FilledButton.icon(
                  onPressed: onDiscover,
                  icon: const Icon(Icons.explore_rounded),
                  label: const Text('Discover'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: onStartOver,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Start over'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two text tabs at the top of the Shorts tab — the only overlay on the
/// player, so videos stay clean (TikTok / ReelShort style).
class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({required this.discover, required this.onChanged});
  final bool discover;
  final ValueChanged<bool> onChanged;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tab('For You', !discover, () => onChanged(false)),
            const SizedBox(width: 22),
            _tab('Discover', discover, () => onChanged(true)),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                shadows: const [Shadow(blurRadius: 8)],
              ),
              child: Text(label),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: selected ? 20 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
