/// Remote config for the Shorts feature, read from `$cdnBase/shorts/config.json`.
///
/// Every field has a safe default so a missing or partial file never crashes
/// the app. A missing file means the feature stays hidden (`enabled: false`).
class ShortsConfig {
  final bool enabled;
  final int dataVersion;
  final int minBuild;
  final bool useSignedUrls;
  final int freeEpisodesDefault;

  /// Live players kept in memory (current + neighbours). 2 = low-RAM mode.
  final int maxPlayers;
  final ShortsAdsConfig ads;

  const ShortsConfig({
    required this.enabled,
    required this.dataVersion,
    required this.minBuild,
    required this.useSignedUrls,
    required this.freeEpisodesDefault,
    required this.maxPlayers,
    required this.ads,
  });

  static const ShortsConfig disabled = ShortsConfig(
    enabled: false,
    dataVersion: 0,
    minBuild: 0,
    useSignedUrls: false,
    freeEpisodesDefault: 10,
    maxPlayers: 3,
    ads: ShortsAdsConfig.defaults,
  );

  factory ShortsConfig.fromJson(Map<String, dynamic> json) {
    final ads = json['ads'];
    return ShortsConfig(
      enabled: _bool(json['enabled'], false),
      dataVersion: _int(json['data_version'], 0),
      minBuild: _int(json['min_build'], 0),
      useSignedUrls: _bool(json['use_signed_urls'], false),
      freeEpisodesDefault: _int(json['free_episodes_default'], 10),
      maxPlayers: _int(json['max_players'], 3).clamp(2, 3),
      ads: ads is Map<String, dynamic>
          ? ShortsAdsConfig.fromJson(ads)
          : ShortsAdsConfig.defaults,
    );
  }
}

/// Ad rules for Shorts — all controllable from the admin panel, no app update.
///
/// Interstitial: shown when the user moves to a new episode, every
/// [interstitialEveryNEpisodes] episodes, but not before
/// [interstitialFirstAfter] episodes have been watched in this session.
///
/// Rewarded: unlocks [unlockEpisodesPerAd] locked episodes per ad.
/// When [rewardedUnlockEnabled] is false, nothing is locked.
///
/// The existing ad admin config still applies on top of this (global ads
/// on/off, cooldown, max per session) via the screen keys below.
class ShortsAdsConfig {
  final bool interstitialEnabled;
  final int interstitialEveryNEpisodes;
  final int interstitialFirstAfter;
  final String interstitialScreenKey;
  final bool rewardedUnlockEnabled;
  final int unlockEpisodesPerAd;
  final bool unlockOnNoFill;
  final String rewardedScreenKey;

  const ShortsAdsConfig({
    required this.interstitialEnabled,
    required this.interstitialEveryNEpisodes,
    required this.interstitialFirstAfter,
    required this.interstitialScreenKey,
    required this.rewardedUnlockEnabled,
    required this.unlockEpisodesPerAd,
    required this.unlockOnNoFill,
    required this.rewardedScreenKey,
  });

  static const ShortsAdsConfig defaults = ShortsAdsConfig(
    interstitialEnabled: true,
    interstitialEveryNEpisodes: 4,
    interstitialFirstAfter: 3,
    interstitialScreenKey: 'shorts_feed',
    rewardedUnlockEnabled: true,
    unlockEpisodesPerAd: 3,
    unlockOnNoFill: false,
    rewardedScreenKey: 'shorts_unlock',
  );

  factory ShortsAdsConfig.fromJson(Map<String, dynamic> json) {
    const d = defaults;
    return ShortsAdsConfig(
      interstitialEnabled: _bool(
        json['interstitial_enabled'],
        d.interstitialEnabled,
      ),
      interstitialEveryNEpisodes: _int(
        json['interstitial_every_n_episodes'],
        d.interstitialEveryNEpisodes,
      ).clamp(1, 1000),
      interstitialFirstAfter: _int(
        json['interstitial_first_after'],
        d.interstitialFirstAfter,
      ).clamp(0, 1000),
      interstitialScreenKey: _str(
        json['interstitial_screen_key'],
        d.interstitialScreenKey,
      ),
      rewardedUnlockEnabled: _bool(
        json['rewarded_unlock_enabled'],
        d.rewardedUnlockEnabled,
      ),
      unlockEpisodesPerAd: _int(
        json['unlock_episodes_per_ad'],
        d.unlockEpisodesPerAd,
      ).clamp(1, 1000),
      unlockOnNoFill: _bool(json['unlock_on_no_fill'], d.unlockOnNoFill),
      rewardedScreenKey: _str(
        json['rewarded_screen_key'],
        d.rewardedScreenKey,
      ),
    );
  }
}

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

int _int(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _str(Object? v, String fallback) =>
    v is String && v.trim().isNotEmpty ? v.trim() : fallback;
