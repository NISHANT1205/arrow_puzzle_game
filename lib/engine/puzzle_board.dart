// lib/engine/puzzle_board.dart
//
// Pure game rules, no Flutter imports.
//
// Rule: tapping an arrow makes it slide forward along its own body and then
// straight ahead in the direction its head points. It escapes if every cell
// from the head to the edge of the board is empty. Otherwise it travels until
// its head bumps into the first arrow in the way and snaps back — the tap is
// a mistake and costs a life.

import '../models/arrow_path.dart';

/// Outcome of checking (or performing) a tap.
sealed class MoveResult {
  const MoveResult(this.arrow);
  final ArrowPath arrow;
}

/// The arrow leaves the board. [exitSteps] is how many cells the head travels
/// before it is past the edge.
class Escaped extends MoveResult {
  const Escaped(super.arrow, this.exitSteps);
  final int exitSteps;
}

/// The arrow is blocked. The head can travel [freeSteps] empty cells before
/// it hits [blocker] at [hitCell].
class Blocked extends MoveResult {
  const Blocked(super.arrow, this.freeSteps, this.blocker, this.hitCell);
  final int freeSteps;
  final ArrowPath blocker;
  final Cell hitCell;
}

class PuzzleBoard {
  PuzzleBoard({
    required this.rows,
    required this.cols,
    required Iterable<ArrowPath> arrows,
  }) {
    for (final a in arrows) {
      add(a);
    }
  }

  final int rows;
  final int cols;

  final Map<int, ArrowPath> _arrows = {};
  final Map<Cell, int> _occupancy = {};

  Iterable<ArrowPath> get arrows => _arrows.values;
  int get count => _arrows.length;
  bool get isCleared => _arrows.isEmpty;

  bool inBounds(Cell c) =>
      c.row >= 0 && c.row < rows && c.col >= 0 && c.col < cols;

  bool isEmpty(Cell c) => !_occupancy.containsKey(c);

  ArrowPath? arrowById(int id) => _arrows[id];

  ArrowPath? arrowAt(Cell c) {
    final id = _occupancy[c];
    return id == null ? null : _arrows[id];
  }

  void add(ArrowPath arrow) {
    for (final c in arrow.cells) {
      if (!inBounds(c)) {
        throw ArgumentError('$arrow leaves the ${cols}x$rows board');
      }
      if (_occupancy.containsKey(c)) {
        throw ArgumentError('$arrow overlaps arrow #${_occupancy[c]} at $c');
      }
    }
    _arrows[arrow.id] = arrow;
    for (final c in arrow.cells) {
      _occupancy[c] = arrow.id;
    }
  }

  void remove(int id) {
    final arrow = _arrows.remove(id);
    if (arrow == null) return;
    for (final c in arrow.cells) {
      _occupancy.remove(c);
    }
  }

  /// What would happen if [arrow] were tapped now. Does not change the board.
  MoveResult evaluate(ArrowPath arrow) {
    final dir = arrow.direction;
    var cell = arrow.head.step(dir);
    var steps = 0;
    while (inBounds(cell)) {
      final other = _occupancy[cell];
      if (other != null) {
        return Blocked(arrow, steps, _arrows[other]!, cell);
      }
      steps++;
      cell = cell.step(dir);
    }
    return Escaped(arrow, steps + 1);
  }

  bool canEscape(ArrowPath arrow) => evaluate(arrow) is Escaped;

  /// Taps [arrow]: removes it when it escapes, leaves the board untouched when
  /// it is blocked.
  MoveResult tap(ArrowPath arrow) {
    final result = evaluate(arrow);
    if (result is Escaped) remove(arrow.id);
    return result;
  }

  /// Arrows that can leave right now.
  List<ArrowPath> freeArrows() => [
        for (final a in _arrows.values)
          if (canEscape(a)) a,
      ];

  /// Removing an arrow only ever frees cells, so repeatedly removing any free
  /// arrow clears the board exactly when the puzzle is solvable. Returns a
  /// full clearing order, or null when the board is stuck.
  List<int>? solve() {
    final copy = PuzzleBoard(rows: rows, cols: cols, arrows: arrows);
    final order = <int>[];
    while (!copy.isCleared) {
      final free = copy.freeArrows();
      if (free.isEmpty) return null;
      for (final a in free) {
        copy.remove(a.id);
        order.add(a.id);
      }
    }
    return order;
  }
}
