import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/models/shorts_config_model.dart';
import 'package:drama_hub/features/shorts/services/shorts_local_store.dart';
import 'package:drama_hub/features/shorts/services/shorts_player_factory.dart';
import 'package:drama_hub/features/shorts/services/shorts_player_pool.dart';
import 'package:drama_hub/features/shorts/services/shorts_repository.dart';
import 'package:drama_hub/features/shorts/services/shorts_rules.dart';
import 'package:drama_hub/services/ad_service.dart';

enum ShortsMode { feed, series }

/// Drives one vertical player screen (feed or series).
///
/// Playback is derived from a few flags in [_sync]; nothing else calls
/// play()/pause() directly, so app lifecycle, route changes, tab switches
/// and ads can never fight each other.
class ShortsPlaybackController extends ChangeNotifier {
  ShortsPlaybackController({required this.mode, this.onEnded}) {
    _mutedSub = _store.muted.listen((_) => _sync());
    if (Get.isRegistered<AdService>()) {
      AdService.instance.preloadShortsAds();
    }
  }

  late final StreamSubscription<bool> _mutedSub;

  final ShortsMode mode;

  /// Fix #3 — separate cadence per mode so feed and series episodes don't
  /// share the same interstitial counter.
  late final ShortsAdCadence _cadence = ShortsAdCadence(
    name: mode == ShortsMode.feed ? 'feed' : 'series',
  );

  /// Called once when the current episode plays to the end.
  final void Function(int index)? onEnded;

  final ShortsLocalStore _store = ShortsLocalStore.instance;
  ShortsConfig get _config => ShortsRepository.instance.config.value;

  List<ShortItem> _items = const [];
  List<ShortItem> get items => _items;

  late ShortsPlayerPool<VideoPlayerController> _pool = _newPool();
  ShortsPlayerPool<VideoPlayerController> get pool => _pool;

  final ValueNotifier<int> current = ValueNotifier(0);
  final ValueNotifier<bool> userPaused = ValueNotifier(false);
  final ValueNotifier<bool> boosted = ValueNotifier(false);
  final ValueNotifier<bool> ended = ValueNotifier(false);

  bool _appActive = true;
  bool _visible = true;
  bool _routeCurrent = true;
  bool _adShowing = false;
  bool _atEndPage = false;
  bool _disposed = false;

  VideoPlayerController? _listened;
  final Set<int> _restored = {};
  Duration _lastSaved = Duration.zero;
  bool _endHandled = false;
  bool _wakelockOn = false;
  bool _errorLogged = false;

  ShortsPlayerPool<VideoPlayerController> _newPool() =>
      ShortsPlayerPool<VideoPlayerController>(
        maxPlayers: _config.maxPlayers,
        canLoad: (i) => i >= 0 && i < _items.length && !isLocked(i),
        create: (i) => ShortsPlayerFactory.create(_items[i]),
        destroy: (c) => c.dispose(),
      )..addListener(_onPoolChanged);

  // ── Setup ────────────────────────────────────────────────────────────────

  void setItems(List<ShortItem> items, {int initialIndex = 0}) {
    _saveCurrentPosition();
    _detachListener();
    _pool.removeListener(_onPoolChanged);
    _pool.dispose();
    _pool = _newPool();
    _items = List.unmodifiable(items);
    _restored.clear();
    if (_items.isEmpty) {
      notifyListeners();
      return;
    }
    final start = initialIndex.clamp(0, _items.length - 1);
    current.value = start;
    _enterPage(start, countForAds: true);
    notifyListeners();
  }

  /// Adds more items at the end (feed paging) without touching players.
  void appendItems(List<ShortItem> more) {
    if (_disposed || more.isEmpty) return;
    _items = List.unmodifiable([..._items, ...more]);
    if (_pool.focusIndex >= 0) _pool.focus(current.value, _items.length);
    notifyListeners();
  }

  /// True while the "all caught up" page (after the last video) shows.
  void setAtEndPage(bool value) {
    if (_atEndPage == value) return;
    _atEndPage = value;
    _sync();
  }

  // ── Page changes ─────────────────────────────────────────────────────────

  void onPageChanged(int index) {
    if (index == current.value || index < 0 || index >= _items.length) return;
    _saveCurrentPosition();
    current.value = index;
    _enterPage(index, countForAds: true);
  }

  void _enterPage(int index, {required bool countForAds}) {
    userPaused.value = false;
    boosted.value = false;
    ended.value = false;
    _endHandled = false;
    _lastSaved = Duration.zero;
    _pool.focus(index, _items.length);

    final item = _items[index];
    if (!isLocked(index)) {
      // Feed previews are browsing, not watching — only binge mode counts.
      if (mode == ShortsMode.series) {
        _store.setLastWatched(_summary(item.series), item.episode.number);
      } else {
        _store.markSeen(item.series.id);
      }
      if (countForAds && _cadence.onEpisodeStarted(_config.ads)) {
        _showInterstitial();
      }
    }
    _attachListener();
    _sync();
    _log('shorts_view', item);
  }

  // ── Flags from the UI ────────────────────────────────────────────────────

  void setAppActive(bool value) {
    if (_appActive == value) return;
    _appActive = value;
    if (!value) _saveCurrentPosition();
    _sync();
  }

  /// False when another route, sheet or dialog covers this screen.
  void setRouteCurrent(bool value) {
    if (_routeCurrent == value) return;
    _routeCurrent = value;
    if (!value) _saveCurrentPosition();
    _sync();
  }

  /// False when the screen is hidden, e.g. the Shorts tab isn't selected.
  void setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    if (!value) _saveCurrentPosition();
    _sync();
  }

  /// Frees all video decoders (e.g. tab hidden, or another player screen
  /// opens on top). The page index is kept so [restorePlayers] resumes
  /// at the same spot.
  void releasePlayers() {
    _saveCurrentPosition();
    _detachListener();
    _pool.clear();
    _restored.clear();
    _setWakelock(false);
  }

  void restorePlayers() {
    if (_disposed || _items.isEmpty || _pool.focusIndex >= 0) return;
    _pool.focus(current.value, _items.length);
    _attachListener();
    _sync();
  }

  void togglePause() {
    if (ended.value) {
      replay();
      return;
    }
    userPaused.value = !userPaused.value;
    _sync();
  }

  void setBoost(bool on) {
    boosted.value = on;
    playerAt(current.value)?.setPlaybackSpeed(on ? 2.0 : 1.0);
  }

  Future<void> seekTo(Duration position) async {
    final c = playerAt(current.value);
    if (c == null) return;
    ended.value = false;
    _endHandled = false;
    await c.seekTo(position);
    _sync();
  }

  void replay() {
    ended.value = false;
    _endHandled = false;
    userPaused.value = false;
    playerAt(current.value)?.seekTo(Duration.zero);
    _sync();
  }

  void toggleMute() => _store.setMuted(!_store.muted.value);

  void retry(int index) => _pool.retry(index);

  // ── Locks / unlocks ──────────────────────────────────────────────────────

  bool isLocked(int index) {
    if (index < 0 || index >= _items.length) return false;
    final item = _items[index];
    return ShortsRules.isLocked(
      series: item.series,
      episode: item.episode,
      config: _config,
      unlockedUpTo: _store.unlockedUpTo(item.series.id),
    );
  }

  /// Shows a rewarded ad and unlocks episodes. Returns true on unlock.
  Future<bool> unlock(int index) async {
    final item = _items[index];
    final ads = _config.ads;
    final completer = Completer<bool>();
    _adShowing = true;
    _sync();

    void grant() {
      _store.unlockUpTo(
        item.series.id,
        ShortsRules.unlockTarget(item.episode.number, ads),
      );
      _log('shorts_unlock', item);
      if (!completer.isCompleted) completer.complete(true);
    }

    try {
      if (!Get.isRegistered<AdService>()) throw StateError('no AdService');
      await AdService.instance.showShortsRewarded(
        onRewarded: grant,
        onNotAvailable: () {
          if (ads.unlockOnNoFill) {
            grant();
          } else if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
    } catch (_) {
      if (ads.unlockOnNoFill) {
        grant();
      } else if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    final ok = await completer.future;
    _adShowing = false;
    if (_disposed) return ok;
    if (ok && index == current.value) {
      _enterPage(index, countForAds: false);
    } else {
      _pool.refresh();
      _sync();
    }
    notifyListeners();
    return ok;
  }

  // ── Player access ────────────────────────────────────────────────────────

  VideoPlayerController? playerAt(int index) => _pool.playerAt(index);

  // ── Internals ────────────────────────────────────────────────────────────

  bool get _shouldPlay =>
      _appActive &&
      _visible &&
      _routeCurrent &&
      !_adShowing &&
      !_atEndPage &&
      !userPaused.value &&
      !ended.value &&
      !isLocked(current.value);

  void _sync() {
    if (_disposed) return;
    final cur = current.value;
    final volume = _store.muted.value ? 0.0 : 1.0;
    var playing = false;

    for (final entry in _pool.readyPlayers) {
      final c = entry.value;
      if (c.value.volume != volume) c.setVolume(volume);
      if (entry.key == cur && _shouldPlay && _restored.contains(cur)) {
        if (!c.value.isPlaying) c.play();
        playing = true;
      } else if (c.value.isPlaying) {
        c.pause();
      }
    }
    _setWakelock(playing);
  }

  void _onPoolChanged() {
    if (_disposed) return;
    for (final entry in _pool.readyPlayers) {
      if (_restored.contains(entry.key)) continue;
      _restored.add(entry.key);
      _restorePosition(entry.key, entry.value);
    }
    // Pages listen to the pool directly; no need to rebuild the PageView.
    _attachListener();
    _sync();
  }

  /// Resume where the user left off, unless near the start or end.
  void _restorePosition(int index, VideoPlayerController c) {
    final saved = _store.position(_items[index].key);
    final total = c.value.duration;
    if (saved > const Duration(seconds: 3) &&
        saved < total - const Duration(seconds: 5)) {
      c.seekTo(saved);
    }
  }

  void _attachListener() {
    final c = playerAt(current.value);
    if (identical(c, _listened)) return;
    _detachListener();
    _listened = c;
    _errorLogged = false;
    c?.addListener(_onPlayerTick);
  }

  void _detachListener() {
    _listened?.removeListener(_onPlayerTick);
    _listened = null;
  }

  void _onPlayerTick() {
    final c = _listened;
    if (c == null || _disposed) return;
    final v = c.value;

    if (v.hasError) {
      if (!_errorLogged) {
        _errorLogged = true;
        _recordError(v.errorDescription);
      }
      return;
    }

    if ((v.position - _lastSaved).abs() > const Duration(seconds: 5)) {
      _lastSaved = v.position;
      _store.savePosition(_items[current.value].key, v.position);
    }

    final atEnd =
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 300) &&
        !v.isPlaying;
    if (atEnd && !_endHandled) {
      _endHandled = true;
      final item = _items[current.value];
      _store.clearPosition(item.key);
      _log('shorts_complete', item);
      ended.value = true;
      _sync();
      onEnded?.call(current.value);
    }
  }

  Future<void> _showInterstitial() async {
    if (!Get.isRegistered<AdService>()) return;
    // Let the page settle first so the ad never cuts a swipe animation.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_disposed || !_appActive || !_visible || !_routeCurrent) return;
    _adShowing = true;
    _sync();
    try {
      // Fix #1 — only reset the cadence counter when the ad was actually
      // displayed. On no-fill / timeout, the counter stays at the threshold
      // and the next episode retries immediately.
      final shown = await AdService.instance.showShortsInterstitial();
      if (shown) _cadence.confirmAdShown();
    } catch (_) {}
    _adShowing = false;
    _sync();
  }

  void _saveCurrentPosition() {
    if (_items.isEmpty) return;
    final c = playerAt(current.value);
    if (c == null || !c.value.isInitialized || ended.value) return;
    _store.savePosition(_items[current.value].key, c.value.position);
  }

  void _setWakelock(bool on) {
    if (_wakelockOn == on) return;
    _wakelockOn = on;
    (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});
  }

  void _recordError(String? description) {
    if (kDebugMode) debugPrint('Shorts player error: $description');
    try {
      FirebaseCrashlytics.instance.recordError(
        'Shorts player error: $description',
        null,
        reason: 'shorts_player',
        fatal: false,
      );
    } catch (_) {}
  }

  void _log(String name, ShortItem item) {
    try {
      FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: {
          'series_id': item.series.id,
          'episode': item.episode.number,
          'mode': mode.name,
        },
      );
    } catch (_) {}
  }

  static SavedShortSeries _summary(ShortSeries s) => SavedShortSeries(
    id: s.id,
    title: s.title,
    posterUrl: s.posterUrl,
    totalEpisodes: s.totalEpisodes,
  );

  @override
  void dispose() {
    _saveCurrentPosition();
    _disposed = true;
    _mutedSub.cancel();
    _detachListener();
    _pool.removeListener(_onPoolChanged);
    _pool.dispose();
    _setWakelock(false);
    current.dispose();
    userPaused.dispose();
    boosted.dispose();
    ended.dispose();
    super.dispose();
  }
}

/// Exposed for UI: summary for My List.
SavedShortSeries shortsSummaryOf(ShortSeries s) =>
    ShortsPlaybackController._summary(s);
