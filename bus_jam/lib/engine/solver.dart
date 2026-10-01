import 'game_state.dart';

/// Depth-first search over tap orders with memoisation and move ordering:
/// vehicles whose colour the queue needs soonest are tried first.
class Solver {
  final int nodeLimit;
  int nodes = 0;
  final Set<String> _seen = {};

  Solver({this.nodeLimit = 200000});

  List<int>? solve(GameState start) {
    nodes = 0;
    _seen.clear();
    final path = <int>[];
    return _dfs(start.copy(), path) ? path : null;
  }

  bool _dfs(GameState s, List<int> path) {
    if (s.isWon) return true;
    if (++nodes > nodeLimit || !_seen.add(s.key)) return false;
    for (final m in _ordered(s)) {
      final next = s.copy()..tap(m);
      path.add(m);
      if (_dfs(next, path)) return true;
      path.removeLast();
      if (nodes > nodeLimit) return false;
    }
    return false;
  }

  List<int> _ordered(GameState s) {
    final level = s.level;
    final moves = s.legalMoves();
    final firstNeed = <int, int>{};
    for (var i = s.front; i < level.queue.length; i++) {
      firstNeed.putIfAbsent(level.queue[i], () => i - s.front);
      if (firstNeed.length >= 12) break;
    }
    // Seats already waiting at the station per colour.
    final waiting = <int, int>{};
    for (final b in s.bays) {
      if (b == null) continue;
      final v = level.vehicles[b.vehicle];
      waiting[v.color] = (waiting[v.color] ?? 0) + v.seats - b.filled;
    }
    int score(int m) {
      final v = level.vehicles[m];
      final need = firstNeed[v.color] ?? 1000;
      final covered = (waiting[v.color] ?? 0) > need ? 500 : 0;
      return need + covered;
    }

    moves.sort((a, b) => score(a).compareTo(score(b)));
    return moves;
  }
}
