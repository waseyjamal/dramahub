import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drama_hub/features/shorts/services/shorts_data_service.dart';

void main() {
  late Map<String, http.Response Function()> routes;
  late int calls;

  ShortsDataService service() => ShortsDataService(
    baseUrl: () => 'https://cdn.test',
    client: MockClient((req) async {
      calls++;
      final handler = routes[req.url.path];
      if (handler == null) return http.Response('not found', 404);
      return handler();
    }),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    routes = {};
    calls = 0;
  });

  final feedJson = jsonEncode([
    {
      'id': 'a',
      'title': 'A',
      'episode': {'n': 1, 'hls': 'https://v/a1.m3u8'},
    },
    {'id': 'broken'},
  ]);

  test('config 404 → disabled; no config cached → disabled', () async {
    final s = service();
    expect((await s.fetchConfig())!.enabled, isFalse);
    expect((await s.cachedConfig()).enabled, isFalse);
  });

  test('config is cached for next startup', () async {
    routes['/shorts/config.json'] = () =>
        http.Response(jsonEncode({'enabled': true, 'data_version': 2}), 200);
    final s = service();
    expect((await s.fetchConfig())!.enabled, isTrue);
    expect((await s.cachedConfig()).enabled, isTrue);
  });

  test('network error on config → null (keep cached)', () async {
    routes['/shorts/config.json'] = () => throw Exception('offline');
    expect(await service().fetchConfig(), isNull);
  });

  test('feed parses valid entries and is cached', () async {
    routes['/shorts/feed.json'] = () => http.Response(feedJson, 200);
    final s = service();
    final feed = await s.loadFeed();
    expect(feed.length, 1);
    expect(feed.first.series.id, 'a');
    await s.loadFeed();
    expect(calls, 1, reason: 'second load served from cache');
  });

  test('stale cache served when network fails', () async {
    routes['/shorts/feed.json'] = () => http.Response(feedJson, 200);
    final s = service();
    await s.loadFeed();
    routes['/shorts/feed.json'] = () => throw Exception('offline');
    final feed = await s.loadFeed(forceRefresh: true);
    expect(feed.length, 1);
  });

  test('no cache + network failure → ShortsLoadException', () async {
    expect(service().loadFeed(), throwsA(isA<ShortsLoadException>()));
  });

  test('data_version change clears cached feed', () async {
    routes['/shorts/feed.json'] = () => http.Response(feedJson, 200);
    routes['/shorts/config.json'] = () =>
        http.Response(jsonEncode({'enabled': true, 'data_version': 1}), 200);
    final s = service();
    await s.fetchConfig();
    await s.loadFeed();
    routes['/shorts/config.json'] = () =>
        http.Response(jsonEncode({'enabled': true, 'data_version': 2}), 200);
    await s.fetchConfig();
    calls = 0;
    await s.loadFeed();
    expect(calls, 1, reason: 'cache busted → refetched');
  });

  test('series without playable episodes → exception', () async {
    routes['/shorts/series/x.json'] = () =>
        http.Response(jsonEncode({'id': 'x', 'episodes': []}), 200);
    expect(service().loadSeries('x'), throwsA(isA<ShortsLoadException>()));
  });
}
