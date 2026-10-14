import 'package:flutter_test/flutter_test.dart';

import 'package:drama_hub/features/shorts/services/shorts_feed_ranker.dart';

void main() {
  List<String> rank(
    List<String> ids, {
    Set<String> seen = const {},
    Set<String> started = const {},
    int seed = 1,
  }) => ShortsFeedRanker.rank(
    ids,
    idOf: (s) => s,
    seen: seen,
    started: started,
    seed: seed,
  );

  final ids = [for (var i = 0; i < 30; i++) 's$i'];

  test('first unseen series keep admin order (featured)', () {
    expect(rank(ids).take(3), ['s0', 's1', 's2']);
  });

  test('unseen first, then seen, then started', () {
    final r = rank(ids, seen: {'s0', 's5'}, started: {'s1'});
    expect(r.take(3), ['s2', 's3', 's4']); // next unseen become featured
    expect(r.sublist(r.length - 3, r.length - 1).toSet(), {'s0', 's5'});
    expect(r.last, 's1');
  });

  test('keeps every series exactly once and drops duplicates', () {
    final r = rank([...ids, 's3', 's7']);
    expect(r.length, ids.length);
    expect(r.toSet(), ids.toSet());
  });

  test('different seeds give a different order after the featured ones', () {
    expect(rank(ids, seed: 1), isNot(equals(rank(ids, seed: 2))));
    expect(rank(ids, seed: 1).take(3), rank(ids, seed: 2).take(3));
  });

  test('same seed is deterministic', () {
    expect(rank(ids, seed: 42), rank(ids, seed: 42));
  });

  test('empty input', () {
    expect(rank(const []), isEmpty);
  });
}
