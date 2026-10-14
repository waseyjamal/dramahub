import 'package:flutter/foundation.dart';

/// Keeps a small sliding window of live video players around the visible
/// page — the core of smooth reels-style swiping.
///
/// * Window: current ±1 (`maxPlayers` 3) or current/next (`maxPlayers` 2).
/// * Load order: current first, then next, then previous.
/// * Anything outside the window is destroyed immediately (decoders freed).
/// * A player that finishes loading after the user swiped away is
///   destroyed instead of leaked.
///
/// Generic over [T] so the window logic is unit-testable without real
/// video players.
class ShortsPlayerPool<T> extends ChangeNotifier {
  ShortsPlayerPool({
    required this.create,
    required this.destroy,
    required this.canLoad,
    int maxPlayers = 3,
  }) : maxPlayers = maxPlayers.clamp(2, 3);

  final Future<T> Function(int index) create;
  final Future<void> Function(T player) destroy;

  /// False for pages that must not load (e.g. locked episodes).
  final bool Function(int index) canLoad;
  final int maxPlayers;

  final Map<int, T> _ready = {};
  final Map<int, Future<T?>> _pending = {};
  final Map<int, Object> _errors = {};
  Set<int> _window = {};
  int _focus = -1;
  int _length = 0;
  int _generation = 0;
  bool _disposed = false;

  int get focusIndex => _focus;
  T? playerAt(int index) => _ready[index];
  Object? errorAt(int index) => _errors[index];
  bool isLoading(int index) => _pending.containsKey(index);
  Iterable<MapEntry<int, T>> get readyPlayers => _ready.entries;

  /// Indices that should hold a live player when [focus] is visible.
  static Set<int> windowFor(int focus, int length, int maxPlayers) {
    if (length <= 0 || focus < 0 || focus >= length) return {};
    final result = {focus};
    if (focus + 1 < length) result.add(focus + 1);
    if (maxPlayers >= 3 && focus - 1 >= 0) result.add(focus - 1);
    return result;
  }

  /// Call on every page change (and once at start).
  void focus(int index, int length) {
    if (_disposed) return;
    _focus = index;
    _length = length;
    _window = windowFor(index, length, maxPlayers);

    for (final i in _ready.keys.toList()) {
      if (!_window.contains(i)) destroy(_ready.remove(i) as T);
    }
    _errors.removeWhere((i, _) => !_window.contains(i));

    final gen = _generation;
    _ensure(index).whenComplete(() {
      if (_disposed || gen != _generation || _focus != index) return;
      for (final n in [index + 1, index - 1]) {
        if (_window.contains(n)) _ensure(n);
      }
    });
    notifyListeners();
  }

  /// Re-checks the current window — e.g. after an episode was unlocked.
  void refresh() {
    if (_focus >= 0) focus(_focus, _length);
  }

  void retry(int index) {
    if (_errors.remove(index) != null) refresh();
  }

  /// Destroys everything — use when the list of pages is replaced.
  void clear() {
    _generation++;
    for (final p in _ready.values) {
      destroy(p);
    }
    _ready.clear();
    _pending.clear();
    _errors.clear();
    _window = {};
    _focus = -1;
    notifyListeners();
  }

  Future<T?> _ensure(int index) {
    final ready = _ready[index];
    if (ready != null) return Future.value(ready);
    final pending = _pending[index];
    if (pending != null) return pending;
    if (_errors.containsKey(index) || !canLoad(index)) {
      return Future.value(null);
    }

    final gen = _generation;
    final future = create(index).then<T?>(
      (player) async {
        if (_disposed || gen != _generation || !_window.contains(index)) {
          if (gen == _generation) _pending.remove(index);
          await destroy(player);
          return null;
        }
        _pending.remove(index);
        _ready[index] = player;
        notifyListeners();
        return player;
      },
      onError: (Object e) {
        if (_disposed || gen != _generation) return null;
        _pending.remove(index);
        if (_window.contains(index)) {
          _errors[index] = e;
          notifyListeners();
        }
        return null;
      },
    );
    _pending[index] = future;
    return future;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final p in _ready.values) {
      destroy(p);
    }
    _ready.clear();
    _pending.clear();
    super.dispose();
  }
}
