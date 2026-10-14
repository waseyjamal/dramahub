import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/services/shorts_local_store.dart';
import 'package:drama_hub/features/shorts/services/shorts_repository.dart';
import 'package:drama_hub/features/shorts/widgets/shorts_state_views.dart';
import 'package:drama_hub/ui_system/colors.dart';

/// "Discover" page of the Shorts tab — the one place to find any series.
///
/// Search (title / genre / tags) · Continue watching · My List ·
/// genre chips · all-series poster grid. No video players live here.
class ShortsDiscoverView extends StatefulWidget {
  const ShortsDiscoverView({
    super.key,
    required this.topPadding,
    required this.onOpenSeries,
    required this.onSeeMyList,
  });

  /// Space reserved for the For You | Discover switcher above this view.
  final double topPadding;
  final Future<void> Function(String seriesId, int episode) onOpenSeries;
  final Future<void> Function() onSeeMyList;

  @override
  State<ShortsDiscoverView> createState() => _ShortsDiscoverViewState();
}

enum _LoadState { loading, ready, error }

class _ShortsDiscoverViewState extends State<ShortsDiscoverView> {
  final _store = ShortsLocalStore.instance;
  final _search = TextEditingController();

  _LoadState _state = _LoadState.loading;
  List<ShortSeries> _all = const [];
  List<String> _genres = const [];
  String _genre = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (_all.isEmpty) setState(() => _state = _LoadState.loading);
    try {
      await ShortsRepository.instance.init();
      await _store.ensureLoaded();
      final feed = await ShortsRepository.instance.loadFeed(
        forceRefresh: force,
      );
      final seen = <String>{};
      final series = <ShortSeries>[
        for (final e in feed)
          if (seen.add(e.series.id)) e.series,
      ];
      final genres = <String>{
        for (final s in series)
          if (s.genre.isNotEmpty) _cap(s.genre),
      }.toList()..sort();
      if (!mounted) return;
      setState(() {
        _all = series;
        _genres = genres;
        if (!_genres.contains(_genre)) _genre = '';
        _state = _LoadState.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _all.isEmpty ? _LoadState.error : _state);
    }
  }

  static String _cap(String s) {
    final t = s.trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1).toLowerCase();
  }

  int _resumeEpisode(String id) {
    final w = _store.maxWatched(id);
    return w > 0 ? w : 1;
  }

  Future<void> _open(String id) async {
    FocusScope.of(context).unfocus();
    await widget.onOpenSeries(id, _resumeEpisode(id));
    if (mounted) setState(() {}); // progress may have changed
  }

  List<ShortSeries> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((s) {
      if (_genre.isNotEmpty && _cap(s.genre) != _genre) return false;
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Most recently watched first, then other started series.
  List<_Card> get _continue {
    final out = <_Card>[];
    final last = _store.lastWatched.value;
    if (last != null) out.add(_Card.saved(last.series));
    for (final s in _all) {
      if (s.id != last?.series.id && _store.maxWatched(s.id) > 0) {
        out.add(_Card.series(s));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkBackground,
      child: switch (_state) {
        _LoadState.loading => const ShortsLoadingView(),
        _LoadState.error => ShortsMessageView(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load series",
          message: 'Check your connection and try again.',
          onRetry: () => _load(force: true),
        ),
        _LoadState.ready => _content(),
      },
    );
  }

  Widget _content() {
    final items = _filtered;
    final searching = _query.isNotEmpty || _genre.isNotEmpty;
    final cont = searching ? const <_Card>[] : _continue;
    final saved = searching
        ? const <_Card>[]
        : _store.saved.map(_Card.saved).toList();

    return RefreshIndicator(
      edgeOffset: widget.topPadding,
      onRefresh: () => _load(force: true),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: widget.topPadding)),
          SliverToBoxAdapter(child: _searchField()),
          if (cont.isNotEmpty) ...[
            _header('Continue watching'),
            SliverToBoxAdapter(child: _row(cont, progress: true)),
          ],
          if (saved.isNotEmpty) ...[
            _header('My List', onSeeAll: widget.onSeeMyList),
            SliverToBoxAdapter(child: _row(saved)),
          ],
          _header(searching ? 'Results · ${items.length}' : 'All series'),
          if (_genres.length > 1) SliverToBoxAdapter(child: _genreChips()),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No series found',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.52,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final card = _Card.series(items[i]);
                  return _PosterTile(
                    card: card,
                    watched: _store.maxWatched(card.id),
                    onTap: () => _open(card.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    child: TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search dramas, genres…',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: AppColors.cardBackground,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _genreChips() => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        for (final g in ['', ..._genres])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(g.isEmpty ? 'All' : g),
              selected: _genre == g,
              onSelected: (_) => setState(() => _genre = g),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: _genre == g ? Colors.black : Colors.white70,
                fontSize: 12,
              ),
              selectedColor: Colors.white,
              backgroundColor: AppColors.cardBackground,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  );

  Widget _header(String text, {Future<void> Function()? onSeeAll}) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: () async {
                    await onSeeAll();
                    if (mounted) setState(() {});
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
      );

  Widget _row(List<_Card> cards, {bool progress = false}) => SizedBox(
    height: 190,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) => SizedBox(
        width: 100,
        child: _PosterTile(
          card: cards[i],
          watched: _store.maxWatched(cards[i].id),
          onTap: () => _open(cards[i].id),
          showProgress: progress,
        ),
      ),
    ),
  );
}

/// Minimal series info a tile needs (from the feed or from My List).
class _Card {
  final String id;
  final String title;
  final String poster;
  final String genre;
  final int total;

  const _Card(this.id, this.title, this.poster, this.genre, this.total);

  factory _Card.series(ShortSeries s) => _Card(
    s.id,
    s.title,
    s.posterUrl,
    s.genre,
    s.totalEpisodes > 0 ? s.totalEpisodes : s.episodes.length,
  );

  factory _Card.saved(SavedShortSeries s) =>
      _Card(s.id, s.title, s.posterUrl, '', s.totalEpisodes);
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.card,
    required this.watched,
    required this.onTap,
    this.showProgress = false,
  });

  final _Card card;
  final int watched;
  final VoidCallback onTap;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final total = card.total;
    final badge = watched > 0
        ? (total > 0 ? 'EP $watched/$total' : 'EP $watched')
        : (total > 0 ? '$total EP' : '');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  card.poster.isEmpty
                      ? const ColoredBox(color: AppColors.cardBackground)
                      : CachedNetworkImage(
                          imageUrl: card.poster,
                          fit: BoxFit.cover,
                          memCacheWidth: 360,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (_, _) => const ColoredBox(
                            color: AppColors.cardBackground,
                          ),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: AppColors.cardBackground,
                            child: Icon(
                              Icons.movie_rounded,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                  if (badge.isNotEmpty)
                    Positioned(
                      left: 6,
                      bottom: showProgress ? 9 : 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  if (showProgress && total > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: (watched / total).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: Colors.white24,
                        color: AppColors.primaryRed,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          if (card.genre.isNotEmpty && !showProgress)
            Text(
              card.genre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
