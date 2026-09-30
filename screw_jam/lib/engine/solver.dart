import 'game_state.dart';

/// Depth-first search solver with memoisation.
///
/// Moving a free screw straight into an open box of its colour never makes a
/// position worse (it only removes a screw from the board and advances the
/// box queue), so such moves are applied greedily without branching. The
/// search only branches on which screw to park in the tray.
class Solver {
  final int nodeLimit;
  int nodes = 0;
  final Set<String> _seen = {};

  Solver({this.nodeLimit = 200000});

  /// Returns a winning sequence of screw indices from [start], or `null` if
  /// none was found within [nodeLimit] explored states.
  List<int>? solve(GameState start) {
    nodes = 0;
    _seen.clear();
    final path = <int>[];
    return _dfs(start.copy(), path) ? path : null;
  }

  bool _dfs(GameState s, List<int> path) {
    final forcedFrom = path.length;
    // Greedy: drop every screw that has an open box waiting for it.
    while (true) {
      final m = _boxMove(s);
      if (m == null) break;
      s.tap(m);
      path.add(m);
    }
    if (s.isWon) return true;

    if (++nodes > nodeLimit || !_seen.add(s.key)) {
      path.removeRange(forcedFrom, path.length);
      return false;
    }

    for (final m in _bufferMoves(s)) {
      final next = s.copy();
      next.tap(m);
      path.add(m);
      if (_dfs(next, path)) return true;
      path.removeLast();
      if (nodes > nodeLimit) break;
    }
    path.removeRange(forcedFrom, path.length);
    return false;
  }

  int? _boxMove(GameState s) {
    for (final m in s.legalMoves()) {
      if (s.destinationOf(m) == TapResult.toBox) return m;
    }
    return null;
  }

  /// Tray moves ordered by how soon their colour's box arrives, then by
  /// whether they finish off a plate.
  List<int> _bufferMoves(GameState s) {
    final level = s.level;
    final moves = s.legalMoves();
    if (moves.isEmpty) return moves;
    int soon(int color) {
      for (var i = s.nextBox; i < level.boxes.length; i++) {
        if (level.boxes[i] == color) return i - s.nextBox;
      }
      return 1 << 20;
    }

    // Screws of the same colour on the same plate are interchangeable only
    // when they are both free, so deduplicate on (plate, colour).
    final seen = <int>{};
    final unique = <int>[];
    for (final m in moves) {
      final sc = level.screws[m];
      if (seen.add(sc.plate * 64 + sc.color)) unique.add(m);
    }
    unique.sort((a, b) {
      final sa = level.screws[a], sb = level.screws[b];
      final byPlate = s.plateScrewsLeft[sa.plate].compareTo(
        s.plateScrewsLeft[sb.plate],
      );
      final bySoon = soon(sa.color).compareTo(soon(sb.color));
      return bySoon != 0 ? bySoon : byPlate;
    });
    return unique;
  }
}
