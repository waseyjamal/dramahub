import 'package:flutter_test/flutter_test.dart';

import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/models/shorts_config_model.dart';
import 'package:drama_hub/features/shorts/services/shorts_rules.dart';

ShortsConfig _config({
  bool rewarded = true,
  int free = 10,
  int every = 4,
  int firstAfter = 3,
  bool interstitial = true,
}) => ShortsConfig.fromJson({
  'enabled': true,
  'free_episodes_default': free,
  'ads': {
    'interstitial_enabled': interstitial,
    'interstitial_every_n_episodes': every,
    'interstitial_first_after': firstAfter,
    'rewarded_unlock_enabled': rewarded,
    'unlock_episodes_per_ad': 3,
  },
});

void main() {
  group('ShortsConfig', () {
    test('missing/garbage values fall back to safe defaults', () {
      final c = ShortsConfig.fromJson({
        'enabled': 'yes',
        'max_players': 99,
        'ads': 'oops',
      });
      expect(c.enabled, isFalse);
      expect(c.maxPlayers, 3);
      expect(c.ads.interstitialScreenKey, 'shorts_feed');
    });

    test('numeric strings are accepted, ranges clamped', () {
      final c = ShortsConfig.fromJson({
        'enabled': true,
        'data_version': '7',
        'max_players': 1,
        'ads': {'interstitial_every_n_episodes': 0},
      });
      expect(c.dataVersion, 7);
      expect(c.maxPlayers, 2);
      expect(c.ads.interstitialEveryNEpisodes, 1);
    });
  });

  group('ShortSeries parsing', () {
    test('skips bad episodes, dedupes and sorts', () {
      final s = ShortSeries.tryParse({
        'id': 'x',
        'title': 'X',
        'episodes': [
          {'n': 3, 'hls': 'h3'},
          {'n': 1, 'mp4': 'm1'},
          {'n': 1, 'mp4': 'dup'},
          {'n': 2}, // no source
          {'title': 'no number', 'hls': 'h'},
          'garbage',
        ],
      })!;
      expect(s.episodes.map((e) => e.number), [1, 3]);
      expect(s.episodes.first.mp4Url, 'm1');
      expect(s.episodes.first.title, 'Episode 1');
      expect(s.totalEpisodes, 2);
    });

    test('missing id → null', () {
      expect(ShortSeries.tryParse({'title': 'x'}), isNull);
      expect(ShortSeries.tryParse(null), isNull);
    });

    test('feed entry needs a playable episode', () {
      expect(
        ShortFeedEntry.tryParse({
          'id': 's',
          'episode': {'n': 1, 'hls': 'u'},
        }),
        isNotNull,
      );
      expect(
        ShortFeedEntry.tryParse({
          'id': 's',
          'episode': {'n': 1},
        }),
        isNull,
      );
    });
  });

  group('Locking', () {
    const series = ShortSeries(
      id: 's',
      title: '',
      description: '',
      posterUrl: '',
      genre: '',
      tags: [],
      totalEpisodes: 20,
      freeEpisodes: null,
      episodes: [],
    );
    ShortEpisode ep(int n, {bool? locked}) => ShortEpisode(
      number: n,
      title: '',
      hlsUrl: 'u',
      mp4Url: '',
      thumbUrl: '',
      durationSec: 0,
      locked: locked,
    );

    test('free episodes are open, later ones locked', () {
      final c = _config(free: 5);
      expect(ShortsRules.isLocked(series: series, episode: ep(5), config: c, unlockedUpTo: 0), isFalse);
      expect(ShortsRules.isLocked(series: series, episode: ep(6), config: c, unlockedUpTo: 0), isTrue);
    });

    test('unlocked range and explicit flags', () {
      final c = _config(free: 5);
      expect(ShortsRules.isLocked(series: series, episode: ep(7), config: c, unlockedUpTo: 8), isFalse);
      expect(ShortsRules.isLocked(series: series, episode: ep(2, locked: true), config: c, unlockedUpTo: 0), isTrue);
      expect(ShortsRules.isLocked(series: series, episode: ep(9, locked: false), config: c, unlockedUpTo: 0), isFalse);
    });

    test('rewarded disabled → nothing locked', () {
      final c = _config(rewarded: false, free: 1);
      expect(ShortsRules.isLocked(series: series, episode: ep(50, locked: true), config: c, unlockedUpTo: 0), isFalse);
    });

    test('unlock target covers N episodes', () {
      expect(ShortsRules.unlockTarget(6, _config().ads), 8);
    });
  });

  group('Ad cadence', () {
    setUp(ShortsAdCadence.instance.resetForTest);

    List<int> adsAt(ShortsAdsConfig ads, int episodes) {
      ShortsAdCadence.instance.resetForTest();
      final result = <int>[];
      for (var i = 1; i <= episodes; i++) {
        if (ShortsAdCadence.instance.onEpisodeStarted(ads)) {
          result.add(i);
          ShortsAdCadence.instance.confirmAdShown();
        }
      }
      return result;
    }

    test('first after 3, then every 4', () {
      expect(adsAt(_config(every: 4, firstAfter: 3).ads, 13), [4, 8, 12]);
    });

    test('every 2 with grace of 5', () {
      expect(adsAt(_config(every: 2, firstAfter: 5).ads, 10), [6, 8, 10]);
    });

    test('disabled never shows', () {
      expect(adsAt(_config(interstitial: false).ads, 20), isEmpty);
    });
  });
}
