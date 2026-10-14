import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:drama_hub/features/shorts/controllers/shorts_playback_controller.dart';
import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/services/shorts_local_store.dart';
import 'package:drama_hub/features/shorts/services/shorts_repository.dart';
import 'package:drama_hub/features/shorts/services/shorts_rules.dart';
import 'package:drama_hub/features/shorts/widgets/episode_picker_sheet.dart';
import 'package:drama_hub/features/shorts/widgets/shorts_player_view.dart';
import 'package:drama_hub/features/shorts/widgets/shorts_state_views.dart';

class ShortsSeriesArgs {
  final String seriesId;
  final int episode;
  const ShortsSeriesArgs({required this.seriesId, this.episode = 1});
}

/// Binge mode: every episode of one series as a vertical page, auto-next.
class ShortsSeriesScreen extends StatefulWidget {
  const ShortsSeriesScreen({super.key});

  @override
  State<ShortsSeriesScreen> createState() => _ShortsSeriesScreenState();
}

class _ShortsSeriesScreenState extends State<ShortsSeriesScreen> {
  late final ShortsSeriesArgs _args;
  late final ShortsPlaybackController _ctrl = ShortsPlaybackController(
    mode: ShortsMode.series,
    onEnded: _onEnded,
  );
  PageController? _page;
  ShortSeries? _series;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final a = Get.arguments;
    _args = a is ShortsSeriesArgs ? a : const ShortsSeriesArgs(seriesId: '');
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await ShortsRepository.instance.init();
      final series = await ShortsRepository.instance.loadSeries(
        _args.seriesId,
        forceRefresh: force,
      );
      if (!mounted) return;
      final items = series.episodes.map((e) => ShortItem(series, e)).toList();
      var start = series.episodes.indexWhere((e) => e.number == _args.episode);
      if (start < 0) start = 0;
      _page?.dispose();
      _page = PageController(initialPage: start);
      _ctrl.setItems(items, initialIndex: start);
      setState(() {
        _series = series;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onEnded(int index) {
    final page = _page;
    if (page == null || index + 1 >= _ctrl.items.length) return;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _ctrl.current.value != index || !page.hasClients) return;
      page.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openPicker() async {
    final series = _series;
    if (series == null) return;
    final config = ShortsRepository.instance.config.value;
    final store = ShortsLocalStore.instance;
    final chosen = await EpisodePickerSheet.show(
      context,
      series: series,
      currentEpisode: _ctrl.items[_ctrl.current.value].episode.number,
      maxWatched: store.maxWatched(series.id),
      isLocked: (ep) => ShortsRules.isLocked(
        series: series,
        episode: ep,
        config: config,
        unlockedUpTo: store.unlockedUpTo(series.id),
      ),
    );
    if (chosen == null || !mounted) return;
    final idx = series.episodes.indexWhere((e) => e.number == chosen);
    if (idx >= 0) _page?.jumpToPage(idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _page?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_loading)
              const ShortsLoadingView()
            else if (_failed || page == null)
              ShortsMessageView(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load this series",
                message: 'Check your connection and try again.',
                onRetry: () => _load(force: true),
              )
            else
              ShortsPlayerView(
                controller: _ctrl,
                pageController: page,
                onEpisodesTap: (_) => _openPicker(),
              ),
            _TopBar(
              title: _series?.title ?? '',
              controller: _ctrl,
              total: _series?.episodes.length ?? 0,
              onEpisodes: _series == null ? null : _openPicker,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.controller,
    required this.total,
    required this.onEpisodes,
  });
  final String title;
  final ShortsPlaybackController controller;
  final int total;
  final VoidCallback? onEpisodes;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: controller.current,
                builder: (_, cur, _) {
                  final items = controller.items;
                  final ep = cur < items.length ? items[cur].episode.number : 0;
                  return Text(
                    total > 0 ? '$title · EP $ep/$total' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  );
                },
              ),
            ),
            if (onEpisodes != null)
              IconButton(
                icon: const Icon(Icons.format_list_numbered_rounded, color: Colors.white),
                onPressed: onEpisodes,
              ),
          ],
        ),
      ),
    );
  }
}
