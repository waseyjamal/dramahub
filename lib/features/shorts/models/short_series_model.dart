/// One episode of a vertical drama series.
class ShortEpisode {
  final int number;
  final String title;
  final String hlsUrl;
  final String mp4Url;
  final String thumbUrl;
  final int durationSec;

  /// Explicit lock from JSON. Null = decided by the series' free episode count.
  final bool? locked;

  const ShortEpisode({
    required this.number,
    required this.title,
    required this.hlsUrl,
    required this.mp4Url,
    required this.thumbUrl,
    required this.durationSec,
    this.locked,
  });

  bool get hasSource => hlsUrl.isNotEmpty || mp4Url.isNotEmpty;

  /// Returns null when the entry is unusable (no number or no video source).
  static ShortEpisode? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final number = _int(raw['n'] ?? raw['episodeNumber']);
    if (number == null || number <= 0) return null;
    final ep = ShortEpisode(
      number: number,
      title: _str(raw['title']).isEmpty ? 'Episode $number' : _str(raw['title']),
      hlsUrl: _str(raw['hls']),
      mp4Url: _str(raw['mp4']),
      thumbUrl: _str(raw['thumb']),
      durationSec: _int(raw['durationSec']) ?? 0,
      locked: raw['locked'] is bool ? raw['locked'] as bool : null,
    );
    return ep.hasSource ? ep : null;
  }
}

/// A vertical drama series. [episodes] is empty for feed summaries.
class ShortSeries {
  final String id;
  final String title;
  final String description;
  final String posterUrl;
  final String genre;
  final List<String> tags;
  final int totalEpisodes;

  /// Null = use the config default.
  final int? freeEpisodes;
  final List<ShortEpisode> episodes;

  const ShortSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.genre,
    required this.tags,
    required this.totalEpisodes,
    required this.freeEpisodes,
    required this.episodes,
  });

  static ShortSeries? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = _str(raw['id'] ?? raw['seriesId']);
    if (id.isEmpty) return null;

    final episodes = <ShortEpisode>[];
    final rawEpisodes = raw['episodes'];
    if (rawEpisodes is List) {
      final seen = <int>{};
      for (final e in rawEpisodes) {
        final ep = ShortEpisode.tryParse(e);
        if (ep != null && seen.add(ep.number)) episodes.add(ep);
      }
      episodes.sort((a, b) => a.number.compareTo(b.number));
    }

    final tags = raw['tags'] is List
        ? (raw['tags'] as List).whereType<String>().toList()
        : const <String>[];

    return ShortSeries(
      id: id,
      title: _str(raw['title']),
      description: _str(raw['description']),
      posterUrl: _str(raw['poster']),
      genre: _str(raw['genre']),
      tags: tags,
      totalEpisodes: _int(raw['totalEpisodes']) ?? episodes.length,
      freeEpisodes: _int(raw['freeEpisodes']),
      episodes: episodes,
    );
  }

  Map<String, dynamic> toSummaryJson() => {
    'id': id,
    'title': title,
    'poster': posterUrl,
    'totalEpisodes': totalEpisodes,
  };
}

/// One entry of `feed.json`: a series summary plus the episode to preview.
class ShortFeedEntry {
  final ShortSeries series;
  final ShortEpisode episode;

  const ShortFeedEntry(this.series, this.episode);

  static ShortFeedEntry? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final series = ShortSeries.tryParse(raw);
    final episode = ShortEpisode.tryParse(raw['episode']);
    if (series == null || episode == null) return null;
    return ShortFeedEntry(series, episode);
  }
}

/// A single playable page — used by both the feed and the series screen.
class ShortItem {
  final ShortSeries series;
  final ShortEpisode episode;

  const ShortItem(this.series, this.episode);

  String get key => '${series.id}#${episode.number}';
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String _str(Object? v) => v is String ? v.trim() : '';
