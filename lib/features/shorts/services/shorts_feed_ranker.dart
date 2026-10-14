import 'dart:math';

/// Orders the For You feed per user, on device (no backend).
///
/// 1. The first [featuredCount] series the user hasn't seen keep the admin
///    order — new / promoted uploads always reach the top.
/// 2. Other unseen series follow, shuffled.
/// 3. Series already scrolled past come next, shuffled.
/// 4. Series the user started watching go last (they live in
///    Discover → Continue watching).
/// A new [seed] on every app open / pull-to-refresh gives a fresh order.
class ShortsFeedRanker {
  ShortsFeedRanker._();

  static const int featuredCount = 3;

  static List<T> rank<T>(
    List<T> entries, {
    required String Function(T) idOf,
    required Set<String> seen,
    required Set<String> started,
    required int seed,
  }) {
    final rnd = Random(seed);
    final ids = <String>{};
    final fresh = <T>[], seenOnly = <T>[], startedList = <T>[];
    for (final e in entries) {
      final id = idOf(e);
      if (!ids.add(id)) continue;
      if (started.contains(id)) {
        startedList.add(e);
      } else if (seen.contains(id)) {
        seenOnly.add(e);
      } else {
        fresh.add(e);
      }
    }
    final featured = fresh.take(featuredCount).toList();
    final restFresh = fresh.skip(featuredCount).toList()..shuffle(rnd);
    seenOnly.shuffle(rnd);
    startedList.shuffle(rnd);
    return [...featured, ...restFresh, ...seenOnly, ...startedList];
  }
}
