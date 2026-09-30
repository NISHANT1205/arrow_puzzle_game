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

/// Difficulty badge shown on a level. Levels only ever get harder, so the
/// badge marks how far along the curve a level is.
enum LevelTier {
  normal('Normal'),
  hard('Hard'),
  superHard('Super Hard');

  const LevelTier(this.label);
  final String label;

  static LevelTier forLevel(int number) {
    if (number >= 200) return LevelTier.superHard;
    if (number >= 100) return LevelTier.hard;
    return LevelTier.normal;
  }
}

/// Size and density knobs for one level.
class LevelConfig {
  const LevelConfig({
    required this.rows,
    required this.cols,
    required this.minLength,
    required this.maxLength,
    required this.fill,
    required this.straightness,
    required this.aimAcross,
    required this.fillHoles,
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

  /// Probability that a new arrow points across the board (longest clear
  /// lane) instead of a random way. Long lanes get crossed by later arrows,
  /// which creates longer chains of "move that one first".
  final double aimAcross;

  /// Grow arrow tails into leftover holes after placement (off for the
  /// tutorial levels so their arrows stay short).
  final bool fillHoles;
}

class LevelGenerator {
  const LevelGenerator._();

  /// Largest board the generator will build. Big boards are played with
  /// pinch-to-zoom, like the late levels of the original.
  static const int maxCols = 22;
  static const int maxRows = 30;

  /// Knobs for a point on the difficulty curve. [t] runs from 0 (first
  /// level) to 1 (hardest). [extraCols] makes the board bigger than the
  /// curve says; the level builder uses it when a board size runs out of
  /// harder puzzles.
  static LevelConfig configAt(double t, {int extraCols = 0}) {
    t = t.clamp(0.0, 1.0);
    final cols = min(4 + (t * 18).floor() + extraCols, maxCols);
    final rows = min(cols + 1 + cols ~/ 3, maxRows);
    final tutorial = t < .01;
    return LevelConfig(
      rows: rows,
      cols: cols,
      minLength: 2,
      maxLength: 3 + (t * 13).round(),
      fill: tutorial ? .6 : min(.7 + t * .6, .97),
      straightness: .7 - t * .25,
      aimAcross: tutorial ? 0 : .2 + t * .55,
      fillHoles: !tutorial,
    );
  }

  /// Level used after the bundled levels run out: the hardest settings,
  /// best of several tries.
  static Level generate(int number) {
    final config = configAt(1);
    List<ArrowPath> best = const [];
    var bestScore = double.negativeInfinity;
    for (var attempt = 0; attempt < 8; attempt++) {
      final arrows = build(config, number * 7919 + attempt * 104729 + 17);
      final score = difficultyOf(config, arrows).score;
      if (score > bestScore) {
        best = arrows;
        bestScore = score;
      }
    }
    return toLevel(number, config, best);
  }

  /// Difficulty numbers for a set of arrows on [config]'s board.
  static BoardStats difficultyOf(LevelConfig config, List<ArrowPath> arrows) =>
      PuzzleBoard(rows: config.rows, cols: config.cols, arrows: arrows)
          .analyze();

  /// Wraps [arrows] as a playable level, renumbered in a shuffled order so
  /// ids don't leak the solution.
  static Level toLevel(int number, LevelConfig config, List<ArrowPath> arrows) {
    final shuffled = [...arrows]..shuffle(Random(number));
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

  /// One board for [config], fully determined by [seed].
  static List<ArrowPath> build(LevelConfig config, int seed) =>
      _build(config, Random(seed));

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
          final other =
              Cell(rng.nextInt(config.rows), rng.nextInt(config.cols));
          if (_depth(config, other) > _depth(config, head)) head = other;
        }
      }
      final dir = rng.nextDouble() < config.aimAcross
          ? _longestLane(board, head) ?? Dir.values[rng.nextInt(4)]
          : Dir.values[rng.nextInt(4)];
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

    // Tutorial levels keep their short arrows.
    if (config.fillHoles) {
      _extendTails(board, arrows, rng, config.maxLength + 4);
    }
    return arrows;
  }

  /// Fills holes by growing arrow tails into neighbouring empty cells.
  ///
  /// Arrow k is removed before every arrow placed earlier and after every
  /// arrow placed later. So a cell may join arrow k only if no arrow placed
  /// after k needs that cell for its escape lane, and it is not in k's own
  /// lane. Heads never move, so lanes never change and the level stays
  /// solvable. [arrows] is in placement order and is updated in place.
  static void _extendTails(
    PuzzleBoard board,
    List<ArrowPath> arrows,
    Random rng,
    int maxLength,
  ) {
    // For every cell, the latest placed arrow whose lane crosses it.
    final latestLane = <Cell, int>{};
    for (var k = 0; k < arrows.length; k++) {
      final a = arrows[k];
      var c = a.head.step(a.direction);
      while (board.inBounds(c)) {
        latestLane[c] = k;
        c = c.step(a.direction);
      }
    }

    var changed = true;
    while (changed) {
      changed = false;
      final order = [for (var k = 0; k < arrows.length; k++) k]..shuffle(rng);
      for (final k in order) {
        final a = arrows[k];
        if (a.length >= maxLength) continue;
        final dirs = [...Dir.values]..shuffle(rng);
        for (final d in dirs) {
          final c = a.tail.step(d);
          if (!board.inBounds(c) || !board.isEmpty(c)) continue;
          if ((latestLane[c] ?? -1) >= k) continue;
          final grown = ArrowPath(id: a.id, cells: [c, ...a.cells]);
          board.remove(a.id);
          board.add(grown);
          arrows[k] = grown;
          changed = true;
          break;
        }
      }
    }
  }

  /// Direction with the longest clear lane from [head], if any is clear.
  static Dir? _longestLane(PuzzleBoard board, Cell head) {
    Dir? best;
    var bestLength = -1;
    for (final d in Dir.values) {
      final lane = _clearLane(board, head, d, const {});
      if (lane != null && lane.length > bestLength) {
        best = d;
        bestLength = lane.length;
      }
    }
    return best;
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
    final wanted =
        config.minLength + rng.nextInt(config.maxLength - config.minLength + 1);

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
