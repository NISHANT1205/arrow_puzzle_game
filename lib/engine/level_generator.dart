// lib/engine/level_generator.dart
//
// Deterministic, endless level generator.
//
// Levels are built by reverse construction: arrows are placed one at a time,
// and each new arrow's escape lane (the cells straight ahead of its head up to
// the edge) must be empty at the moment it is placed. Later arrows may lie in
// the lanes of earlier ones. Removing arrows in reverse placement order is
// therefore always legal, so every generated level is solvable.
//
// The same level number always produces the same puzzle.

import 'dart:math';

import '../models/arrow_path.dart';
import '../models/level.dart';
import 'puzzle_board.dart';

/// Size and density knobs for one level.
class LevelConfig {
  const LevelConfig({
    required this.rows,
    required this.cols,
    required this.minLength,
    required this.maxLength,
    required this.fill,
    required this.straightness,
  });

  final int rows;
  final int cols;

  /// Arrow length range, in cells (head included).
  final int minLength;
  final int maxLength;

  /// Fraction of the grid the generator tries to cover with arrows.
  final double fill;

  /// Probability that a body keeps going straight instead of turning.
  final double straightness;
}

class LevelGenerator {
  const LevelGenerator._();

  /// Difficulty curve: boards grow, arrows get longer and the grid gets
  /// denser as the level number rises.
  static LevelConfig configFor(int number) {
    final n = max(1, number);
    final cols = min(4 + (n - 1) ~/ 4, 16);
    final rows = min(cols + 1 + cols ~/ 3, 22);
    return LevelConfig(
      rows: rows,
      cols: cols,
      minLength: 2,
      maxLength: min(3 + n ~/ 3, 16),
      fill: min(0.62 + n * 0.008, 0.96),
      straightness: n < 10 ? 0.7 : 0.55,
    );
  }

  /// Candidate boards built per level; the most tightly packed one wins.
  static const int _candidates = 6;

  static Level generate(int number) {
    final config = configFor(number);
    List<ArrowPath> best = const [];
    var bestFilled = -1;
    for (var attempt = 0; attempt < _candidates; attempt++) {
      final rng = Random(number * 7919 + attempt * 104729 + 17);
      final arrows = _build(config, rng);
      final filled = arrows.fold<int>(0, (sum, a) => sum + a.length);
      if (filled > bestFilled) {
        best = arrows;
        bestFilled = filled;
      }
    }

    // Renumber in a shuffled order so ids don't leak the solution.
    final shuffled = [...best]..shuffle(Random(number));
    return Level(
      number: number,
      rows: config.rows,
      cols: config.cols,
      arrows: [
        for (var i = 0; i < shuffled.length; i++)
          ArrowPath(id: i, cells: shuffled[i].cells),
      ],
    );
  }

  /// One candidate board, arrows in placement order.
  static List<ArrowPath> _build(LevelConfig config, Random rng) {
    final board = PuzzleBoard(rows: config.rows, cols: config.cols, arrows: []);
    final arrows = <ArrowPath>[];
    final totalCells = config.rows * config.cols;
    final target = (totalCells * config.fill).round();
    var filled = 0;

    void place(List<Cell> cells) {
      final arrow = ArrowPath(id: arrows.length, cells: cells);
      board.add(arrow);
      arrows.add(arrow);
      filled += cells.length;
    }

    // Random placement.
    var failures = 0;
    while (filled < target && failures < totalCells * 20) {
      // Early arrows (removed last) go deep inside the board; the outer
      // ring is left for the arrows that will leave first.
      var head = Cell(rng.nextInt(config.rows), rng.nextInt(config.cols));
      if (filled < target * .5) {
        for (var i = 0; i < 3; i++) {
          final other = Cell(rng.nextInt(config.rows), rng.nextInt(config.cols));
          if (_depth(config, other) > _depth(config, head)) head = other;
        }
      }
      final dir = Dir.values[rng.nextInt(4)];
      final cells = _grow(board, rng, config, head, dir);
      if (cells == null) {
        failures++;
      } else {
        place(cells);
      }
    }

    // Sweep the remaining gaps: start a body inside each hole and wander
    // until the snake finds a direction it can escape in.
    for (var round = 0; round < 6 && filled < target; round++) {
      final empty = [
        for (var r = 0; r < config.rows; r++)
          for (var c = 0; c < config.cols; c++)
            if (board.isEmpty(Cell(r, c))) Cell(r, c),
      ]..shuffle(rng);
      for (final start in empty) {
        if (filled >= target) break;
        if (!board.isEmpty(start)) continue;
        final cells = _growFromTail(board, rng, config, start);
        if (cells != null) place(cells);
      }
    }

    return arrows;
  }

  static int _depth(LevelConfig config, Cell c) => min(
        min(c.row, config.rows - 1 - c.row),
        min(c.col, config.cols - 1 - c.col),
      );

  /// Cells from [head] (exclusive) to the edge along [dir], or null if any of
  /// them is taken by the board or by [body].
  static List<Cell>? _clearLane(
    PuzzleBoard board,
    Cell head,
    Dir dir,
    Set<Cell> body,
  ) {
    final lane = <Cell>[];
    var c = head.step(dir);
    while (board.inBounds(c)) {
      if (!board.isEmpty(c) || body.contains(c)) return null;
      lane.add(c);
      c = c.step(dir);
    }
    return lane;
  }

  /// Builds an arrow starting with its tail on [start], walking randomly
  /// through empty cells until the current cell works as a head. Returns its
  /// cells tail-to-head, or null if no exit was found.
  static List<Cell>? _growFromTail(
    PuzzleBoard board,
    Random rng,
    LevelConfig config,
    Cell start,
  ) {
    final path = [start];
    final body = {start};
    Dir? heading;
    final limit = config.maxLength + 6;
    while (path.length < limit) {
      final options = [
        for (final d in Dir.values)
          if (d != heading?.opposite &&
              board.inBounds(path.last.step(d)) &&
              board.isEmpty(path.last.step(d)) &&
              !body.contains(path.last.step(d)))
            d,
      ];
      if (options.isEmpty) return null;
      // Take the step that exits right away when there is one.
      Dir? exit;
      for (final d in options..shuffle(rng)) {
        final next = path.last.step(d);
        if (path.length + 1 >= config.minLength &&
            _clearLane(board, next, d, body) != null) {
          exit = d;
          break;
        }
      }
      if (exit != null && (path.length + 1 >= 3 || rng.nextBool())) {
        path.add(path.last.step(exit));
        return path;
      }
      final keep = heading != null &&
          options.contains(heading) &&
          rng.nextDouble() < config.straightness;
      heading = keep ? heading : options[rng.nextInt(options.length)];
      final next = path.last.step(heading);
      path.add(next);
      body.add(next);
    }
    return null;
  }

  /// Tries to build an arrow whose head sits on [head] and points along
  /// [dir]. Returns its cells tail-to-head, or null if it doesn't fit.
  static List<Cell>? _grow(
    PuzzleBoard board,
    Random rng,
    LevelConfig config,
    Cell head,
    Dir dir,
  ) {
    if (!board.isEmpty(head)) return null;

    // The escape lane must be clear right now.
    final lane = <Cell>{};
    var c = head.step(dir);
    while (board.inBounds(c)) {
      if (!board.isEmpty(c)) return null;
      lane.add(c);
      c = c.step(dir);
    }

    bool usable(Cell cell, Set<Cell> body) =>
        board.inBounds(cell) &&
        board.isEmpty(cell) &&
        !lane.contains(cell) &&
        !body.contains(cell);

    // The cell behind the head fixes the head's direction.
    final neck = head.step(dir.opposite);
    final body = <Cell>{head};
    if (!usable(neck, body)) return null;

    final path = [head, neck];
    body.add(neck);
    final wanted = config.minLength +
        rng.nextInt(config.maxLength - config.minLength + 1);

    var heading = dir.opposite; // Direction we walk while growing backwards.
    while (path.length < wanted) {
      final options = <Dir>[];
      final straight = path.last.step(heading);
      if (usable(straight, body) && rng.nextDouble() < config.straightness) {
        options.add(heading);
      } else {
        for (final d in Dir.values) {
          if (d == heading.opposite) continue;
          if (usable(path.last.step(d), body)) options.add(d);
        }
      }
      if (options.isEmpty) break;
      heading = options[rng.nextInt(options.length)];
      final next = path.last.step(heading);
      path.add(next);
      body.add(next);
    }

    return path.reversed.toList();
  }
}
