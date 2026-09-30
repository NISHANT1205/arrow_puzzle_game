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

/// Difficulty badge shown on a level, like the "Hard" / "Super Hard" levels
/// of the original game.
enum LevelTier {
  normal('Normal'),
  hard('Hard'),
  superHard('Super Hard');

  const LevelTier(this.label);
  final String label;
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
    required this.candidates,
    required this.difficultyWeight,
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

  /// Boards built per level; the best-scoring one is kept.
  final int candidates;

  /// How much the candidate score favours hard boards over packed ones.
  final double difficultyWeight;
}

class LevelGenerator {
  const LevelGenerator._();

  /// Every 5th level is Hard and every 10th is Super Hard.
  static LevelTier tierFor(int number) {
    if (number >= 10 && number % 10 == 0) return LevelTier.superHard;
    if (number >= 5 && number % 5 == 0) return LevelTier.hard;
    return LevelTier.normal;
  }

  /// Largest board the generator will build. Big boards are played with
  /// pinch-to-zoom, like the late levels of the original.
  static const int maxCols = 22;
  static const int maxRows = 30;

  /// Difficulty curve: boards grow, arrows get longer, the grid gets denser
  /// and candidates are picked more for difficulty as the level number
  /// rises. Hard and Super Hard levels jump ahead of the curve.
  static LevelConfig configFor(int number) {
    final n = max(1, number);
    final tier = tierFor(n);
    final int boost = switch (tier) {
      LevelTier.normal => 0,
      LevelTier.hard => 2,
      LevelTier.superHard => 4,
    };
    // Fast growth for the first 40 levels, then slowly up to the maximum.
    final int base = min(4 + (n - 1) ~/ 4, 14) + min(max(0, n - 40) ~/ 30, 4);
    final cols = min(base + boost, maxCols);
    final rows = min(cols + 1 + cols ~/ 3, maxRows);
    final ramp = min(n / 100, 1.0); // 0 at level 1, 1 from level 100.
    return LevelConfig(
      rows: rows,
      cols: cols,
      minLength: 2,
      maxLength: min(3 + n ~/ 3, 14) + boost,
      fill: switch (tier) {
        LevelTier.normal => min(0.62 + n * 0.008, 0.94),
        LevelTier.hard => 0.95,
        LevelTier.superHard => 0.97,
      },
      straightness: n < 10 ? 0.7 : 0.55 - ramp * .1,
      aimAcross: n < 5 ? 0 : 0.25 + ramp * .35 + boost * .05,
      candidates: switch (tier) {
        LevelTier.normal => 6,
        LevelTier.hard => 10,
        LevelTier.superHard => 16,
      },
      difficultyWeight: n < 5
          ? 0
          : switch (tier) {
              LevelTier.normal => 0.4 + ramp * 0.6,
              LevelTier.hard => 1.5,
              LevelTier.superHard => 2.5,
            },
    );
  }

  /// Higher is better: packed boards with long dependency chains and few
  /// arrows that are free at the start.
  static double _score(LevelConfig config, List<ArrowPath> arrows) {
    final filled = arrows.fold<int>(0, (sum, a) => sum + a.length);
    final fill = filled / (config.rows * config.cols);
    if (config.difficultyWeight == 0) return fill;
    final stats =
        PuzzleBoard(rows: config.rows, cols: config.cols, arrows: arrows)
            .analyze();
    final depth = stats.layers / sqrt(max(1, stats.arrows));
    return fill + config.difficultyWeight * (depth * .5 + stats.trapRatio);
  }

  static Level generate(int number) {
    final config = configFor(number);
    List<ArrowPath> best = const [];
    var bestScore = double.negativeInfinity;
    for (var attempt = 0; attempt < config.candidates; attempt++) {
      final rng = Random(number * 7919 + attempt * 104729 + 17);
      final arrows = _build(config, rng);
      final score = _score(config, arrows);
      if (score > bestScore) {
        best = arrows;
        bestScore = score;
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
    if (config.difficultyWeight > 0) {
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
