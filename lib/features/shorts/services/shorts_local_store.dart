import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A series summary stored on device (My List / Continue watching).
class SavedShortSeries {
  final String id;
  final String title;
  final String posterUrl;
  final int totalEpisodes;

  const SavedShortSeries({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.totalEpisodes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'poster': posterUrl,
    'totalEpisodes': totalEpisodes,
  };

  static SavedShortSeries? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic> || raw['id'] is! String) return null;
    return SavedShortSeries(
      id: raw['id'] as String,
      title: raw['title'] is String ? raw['title'] as String : '',
      posterUrl: raw['poster'] is String ? raw['poster'] as String : '',
      totalEpisodes: raw['totalEpisodes'] is int
          ? raw['totalEpisodes'] as int
          : 0,
    );
  }
}

class ContinueWatching {
  final SavedShortSeries series;
  final int episode;
  const ContinueWatching(this.series, this.episode);
}

/// All personal Shorts data — on device only, no backend.
/// Uses its own `shorts_` key prefix; never touches existing app keys.
class ShortsLocalStore {
  ShortsLocalStore._();
  static final ShortsLocalStore instance = ShortsLocalStore._();

  static const _kSaved = 'shorts_saved';
  static const _kLast = 'shorts_last';
  static const _kMuted = 'shorts_muted';
  static const _kUnlockedPrefix = 'shorts_unlocked_';
  static const _kWatchedPrefix = 'shorts_watched_';
  static const _kPosPrefix = 'shorts_pos_';
  static const _kPosIndex = 'shorts_pos_index';
  static const _kSeen = 'shorts_seen';
  static const _maxSeen = 2000;

  /// Positions remembered for at most this many episodes (oldest dropped).
  static const int _maxPositions = 300;

  final RxList<SavedShortSeries> saved = <SavedShortSeries>[].obs;
  final Rxn<ContinueWatching> lastWatched = Rxn<ContinueWatching>();
  final RxBool muted = false.obs;

  SharedPreferences? _prefs;
  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      muted.value = p.getBool(_kMuted) ?? false;
      final savedRaw = p.getString(_kSaved);
      if (savedRaw != null) {
        final list = jsonDecode(savedRaw);
        if (list is List) {
          saved.assignAll(
            list.map(SavedShortSeries.tryParse).whereType<SavedShortSeries>(),
          );
        }
      }
      final lastRaw = p.getString(_kLast);
      if (lastRaw != null) {
        final m = jsonDecode(lastRaw);
        final s = SavedShortSeries.tryParse(m is Map ? m['series'] : null);
        final ep = m is Map ? m['episode'] : null;
        if (s != null && ep is int) lastWatched.value = ContinueWatching(s, ep);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ShortsLocalStore load error: $e');
    }
  }

  // ── My List ──────────────────────────────────────────────────────────────

  bool isSaved(String seriesId) => saved.any((s) => s.id == seriesId);

  /// Returns the new saved state.
  bool toggleSaved(SavedShortSeries series) {
    final wasSaved = isSaved(series.id);
    if (wasSaved) {
      saved.removeWhere((s) => s.id == series.id);
    } else {
      saved.insert(0, series);
    }
    _prefs?.setString(
      _kSaved,
      jsonEncode(saved.map((s) => s.toJson()).toList()),
    );
    return !wasSaved;
  }

  // ── Seen in feed (for feed ordering) ──────────────────────────────────────

  /// Series the user has already scrolled past in the For You feed.
  Set<String> get seenIds => (_prefs?.getStringList(_kSeen) ?? const []).toSet();

  void markSeen(String seriesId) {
    final p = _prefs;
    if (p == null) return;
    final list = p.getStringList(_kSeen) ?? <String>[];
    if (list.contains(seriesId)) return;
    list.add(seriesId);
    if (list.length > _maxSeen) list.removeRange(0, list.length - _maxSeen);
    p.setStringList(_kSeen, list);
  }

  // ── Continue watching / progress ─────────────────────────────────────────

  void setLastWatched(SavedShortSeries series, int episode) {
    lastWatched.value = ContinueWatching(series, episode);
    _prefs?.setString(
      _kLast,
      jsonEncode({'series': series.toJson(), 'episode': episode}),
    );
    final watched = maxWatched(series.id);
    if (episode > watched) {
      _prefs?.setInt('$_kWatchedPrefix${series.id}', episode);
    }
  }

  /// Highest episode number the user has opened in this series.
  int maxWatched(String seriesId) =>
      _prefs?.getInt('$_kWatchedPrefix$seriesId') ?? 0;

  Duration position(String itemKey) =>
      Duration(milliseconds: _prefs?.getInt('$_kPosPrefix$itemKey') ?? 0);

  void savePosition(String itemKey, Duration position) {
    final p = _prefs;
    if (p == null) return;
    final index = p.getStringList(_kPosIndex) ?? <String>[];
    index.remove(itemKey);
    index.add(itemKey);
    while (index.length > _maxPositions) {
      p.remove('$_kPosPrefix${index.removeAt(0)}');
    }
    p.setStringList(_kPosIndex, index);
    p.setInt('$_kPosPrefix$itemKey', position.inMilliseconds);
  }

  void clearPosition(String itemKey) => _prefs?.remove('$_kPosPrefix$itemKey');

  // ── Unlocks ──────────────────────────────────────────────────────────────

  /// Highest episode number unlocked by rewarded ads (0 = none).
  int unlockedUpTo(String seriesId) =>
      _prefs?.getInt('$_kUnlockedPrefix$seriesId') ?? 0;

  void unlockUpTo(String seriesId, int episode) {
    if (episode > unlockedUpTo(seriesId)) {
      _prefs?.setInt('$_kUnlockedPrefix$seriesId', episode);
    }
  }

  // ── Mute ─────────────────────────────────────────────────────────────────

  void setMuted(bool value) {
    muted.value = value;
    _prefs?.setBool(_kMuted, value);
  }
}
