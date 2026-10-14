import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:drama_hub/features/shorts/services/shorts_player_pool.dart';

class _FakePlayer {
  _FakePlayer(this.index);
  final int index;
  bool disposed = false;
}

class _Harness {
  _Harness({int maxPlayers = 3, Set<int> locked = const {}}) {
    pool = ShortsPlayerPool<_FakePlayer>(
      maxPlayers: maxPlayers,
      canLoad: (i) => !locked.contains(i),
      create: (i) {
        created.add(i);
        final c = Completer<_FakePlayer>();
        pending[i] = c;
        return c.future;
      },
      destroy: (p) async {
        p.disposed = true;
        destroyed.add(p.index);
      },
    );
  }

  late final ShortsPlayerPool<_FakePlayer> pool;
  final List<int> created = [];
  final List<int> destroyed = [];
  final Map<int, Completer<_FakePlayer>> pending = {};
  final Map<int, _FakePlayer> players = {};

  Future<void> finish(int i) async {
    final p = players[i] = _FakePlayer(i);
    pending.remove(i)!.complete(p);
    await pumpEventQueue();
  }

  Future<void> fail(int i) async {
    pending.remove(i)!.completeError(Exception('boom'));
    await pumpEventQueue();
  }
}

void main() {
  test('window math', () {
    expect(ShortsPlayerPool.windowFor(0, 10, 3), {0, 1});
    expect(ShortsPlayerPool.windowFor(5, 10, 3), {4, 5, 6});
    expect(ShortsPlayerPool.windowFor(9, 10, 3), {8, 9});
    expect(ShortsPlayerPool.windowFor(5, 10, 2), {5, 6});
    expect(ShortsPlayerPool.windowFor(0, 0, 3), isEmpty);
  });

  test('loads current first, then neighbours', () async {
    final h = _Harness();
    h.pool.focus(5, 10);
    expect(h.created, [5]);
    await h.finish(5);
    expect(h.created, [5, 6, 4]);
  });

  test('swiping forward disposes players outside the window', () async {
    final h = _Harness();
    h.pool.focus(1, 10);
    await h.finish(1);
    await h.finish(2);
    await h.finish(0);
    h.pool.focus(2, 10);
    await pumpEventQueue();
    expect(h.destroyed, [0]);
    expect(h.pool.playerAt(1), isNotNull);
    expect(h.pool.playerAt(2), isNotNull);
    expect(h.created.last, 3);
  });

  test('player finishing after user swiped away is destroyed (no leak)', () async {
    final h = _Harness();
    h.pool.focus(0, 10);
    h.pool.focus(5, 10); // rapid jump before 0 loaded
    await h.finish(0);
    expect(h.players[0]!.disposed, isTrue);
    expect(h.pool.playerAt(0), isNull);
  });

  test('never more than maxPlayers alive during rapid swipes', () async {
    final h = _Harness();
    for (var i = 0; i < 30; i++) {
      h.pool.focus(i, 30);
      for (final k in h.pending.keys.toList()) {
        await h.finish(k);
      }
      expect(h.pool.readyPlayers.length, lessThanOrEqualTo(3));
    }
    final alive = h.players.values.where((p) => !p.disposed).length;
    expect(alive, lessThanOrEqualTo(3));
  });

  test('locked pages are not loaded; errors are kept until retry', () async {
    final h = _Harness(locked: {3});
    h.pool.focus(3, 10);
    expect(h.created, isEmpty);

    h.pool.focus(6, 10);
    await h.fail(6);
    expect(h.pool.errorAt(6), isNotNull);
    h.pool.retry(6);
    expect(h.pool.errorAt(6), isNull);
    expect(h.created.where((i) => i == 6).length, 2);
  });

  test('clear() destroys everything and ignores in-flight loads', () async {
    final h = _Harness();
    h.pool.focus(0, 10);
    await h.finish(0);
    h.pool.clear();
    expect(h.players[0]!.disposed, isTrue);
    await h.finish(1);
    expect(h.players[1]!.disposed, isTrue);
    expect(h.pool.readyPlayers, isEmpty);
  });

  test('dispose destroys ready players', () async {
    final h = _Harness();
    h.pool.focus(0, 10);
    await h.finish(0);
    h.pool.dispose();
    expect(h.players[0]!.disposed, isTrue);
  });
}
