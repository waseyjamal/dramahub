import 'package:shared_preferences/shared_preferences.dart';

import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/models/shorts_config_model.dart';


/// Pure business rules for Shorts — no Flutter, easy to unit test.
class ShortsRules {
  ShortsRules._();

  static bool isLocked({
    required ShortSeries series,
    required ShortEpisode episode,
    required ShortsConfig config,
    required int unlockedUpTo,
  }) {
    if (!config.ads.rewardedUnlockEnabled) return false;
    if (episode.number <= unlockedUpTo) return false;
    final explicit = episode.locked;
    if (explicit != null) return explicit;
    final free = series.freeEpisodes ?? config.freeEpisodesDefault;
    return episode.number > free;
  }

  /// Episode number to unlock up to after one rewarded ad, starting at
  /// [from] (the locked episode the user tapped).
  static int unlockTarget(int from, ShortsAdsConfig ads) =>
      from + ads.unlockEpisodesPerAd - 1;
}

/// Tracks how many episodes the user has watched and decides when an
/// interstitial is due.
///
/// Three fixes applied:
///   1. [confirmAdShown] — counter only resets when the ad was actually
///      displayed. If the ad had no fill, the counter stays at the threshold
///      and the next episode retries immediately.
///   2. Persistence — [_sinceLastAd] survives app restarts (SharedPreferences).
///      On every cold start the first episode is always free: the user must
///      watch at least one short before an ad can appear, even if the counter
///      was already at the threshold when they closed the app.
///   3. Named instances — feed and series each get their own cadence so
///      browsing the feed doesn't eat into the binge-mode budget and vice versa.
///
/// Usage:
///   final cadence = ShortsAdCadence(name: 'feed');   // or 'series'
///   if (cadence.onEpisodeStarted(ads)) {
///     final shown = await AdService.instance.showShortsInterstitial();
///     if (shown) cadence.confirmAdShown();
///   }
class ShortsAdCadence {
  ShortsAdCadence({required this.name}) {
    _loadFromDisk(); // fire-and-forget; safe even if episodes start before it completes
  }

  static final ShortsAdCadence instance = ShortsAdCadence(name: 'default');

  /// Identifies this cadence in SharedPreferences (e.g. 'feed' or 'series').
  final String name;

  String get _prefKey => 'shorts_cadence_${name}_since_last_ad';

  // ── In-memory state ──────────────────────────────────────────────────────

  /// How many unlocked episodes have started since the last confirmed ad show.
  /// Persisted across app restarts.
  int _sinceLastAd = 0;

  /// Episodes started in THIS cold-start session. Never persisted.
  /// Ensures the first episode of every session is always free.
  int _thisSession = 0;

  // ── Disk load ─────────────────────────────────────────────────────────────

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sinceLastAd = prefs.getInt(_prefKey) ?? 0;
    } catch (_) {}
  }

  void _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, _sinceLastAd);
    } catch (_) {}
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call when the user moves to a new (unlocked) episode.
  /// Returns true when an interstitial should be attempted.
  ///
  /// If this returns true and [confirmAdShown] is never called (no fill /
  /// timeout), the counter stays at the threshold and the next episode
  /// will also return true — retrying until an ad actually shows.
  bool onEpisodeStarted(ShortsAdsConfig ads) {
    if (!ads.interstitialEnabled) return false;

    _sinceLastAd++;
    _thisSession++;
    _saveToDisk();

    // Fix #2 — cold-start grace period: the very first episode of every
    // session is always free, regardless of what counter was saved to disk.
    if (_thisSession <= 1) return false;

    // For a fresh session, also respect [interstitialFirstAfter].
    final minGrace = (_sinceLastAd == _thisSession) ? ads.interstitialFirstAfter : 1;
    if (_thisSession <= minGrace) return false;

    if (_sinceLastAd < ads.interstitialEveryNEpisodes) return false;

    // Counter is at or past the threshold — signal that an ad should be shown.
    // Do NOT reset here; reset only in [confirmAdShown] after it actually shows.
    return true;
  }

  /// Call ONLY when the interstitial was successfully displayed (i.e.
  /// [AdService.showShortsInterstitial] returned true).
  /// Resets the counter so the cadence restarts from zero.
  void confirmAdShown() {
    _sinceLastAd = 0;
    _saveToDisk();
  }

  void resetForTest() {
    _sinceLastAd = 0;
    _thisSession = 0;
    _saveToDisk();
  }
}
