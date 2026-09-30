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
    this.blockLanes = 0,
    this.minLane = 0,
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

  /// How strongly new arrows are put in the escape lanes of arrows already
  /// on the board (0 = ignore lanes, 1 = always prefer them). Every arrow
  /// placed in another arrow's lane is a trap: that arrow can't leave until
  /// this one is gone. High values mean few free arrows at the start and
  /// long chains of moves that must happen in order.
  final double blockLanes;

  /// Fewest empty cells an arrow needs ahead of its head. An arrow on the
  /// edge pointing straight out can never be trapped, so hard levels ask
  /// for room in front where other arrows can sit.
  final int minLane;
}

class LevelGenerator {
  const LevelGenerator._();

  /// Largest board the generator will build. Big boards are played with
  /// pinch-to-zoom, like the late levels of the original.
  static const int maxCols = 22;
  static const int maxRows = 30;

  /// Number of levels the difficulty schedule is laid out for.
  static const int scheduledLevels = 300;

  /// Board columns for level [number]: slow growth while learning (4 to 11
  /// columns over levels 1-100), fast growth after that (12 to 21 over
  /// levels 101-200), then the biggest board.
  static int colsForLevel(int number) {
    final n = number.clamp(1, scheduledLevels);
    if (n <= 100) return 4 + (8 * (n - 1)) ~/ 100;
    if (n <= 200) return 12 + (10 * (n - 101)) ~/ 100;
    return maxCols;
  }

  /// Difficulty knob position for level [number], from 0 to 1. Rises slowly
  /// to 0.35 by level 100, then steeply to 0.8 by level 200 and on to 1 at
  /// level 300.
  static double difficultyForLevel(int number) {
    final n = number.clamp(1, scheduledLevels);
    if (n <= 100) return .35 * (n - 1) / 99;
    if (n <= 200) return .35 + .45 * (n - 100) / 100;
    return .8 + .2 * (n - 200) / 100;
  }

  /// Knobs for a board with [cols] columns at difficulty [d] (0 to 1).
  static LevelConfig configAt(double d, {required int cols}) {
    d = d.clamp(0.0, 1.0);
    cols = cols.clamp(4, maxCols);
    final rows = min(cols + 1 + cols ~/ 3, maxRows);
    final tutorial = d < .005;
    return LevelConfig(
      rows: rows,
      cols: cols,
      minLength: 2,
      maxLength: 3 + (d * 13).round(),
      fill: tutorial ? .6 : min(.7 + d * .6, .97),
      straightness: .7 - d * .3,
      aimAcross: tutorial ? 0 : .2 + d * .55,
      fillHoles: !tutorial,
      // Traps start just before level 100 and are at full strength from
      // about level 190.
      blockLanes: ((d - .3) / .5).clamp(0.0, 1.0),
      minLane: d < .35
          ? 0
          : d < .6
              ? 1
              : d < .8
                  ? 2
                  : 3,
    );
  }

  /// Knobs for level [number] on the schedule.
  static LevelConfig configForLevel(int number) => configAt(
        difficultyForLevel(number),
        cols: colsForLevel(number),
      );

  /// Level used after the bundled levels run out: the hardest settings,
  /// best of several tries.
  static Level generate(int number) {
    final config = configForLevel(scheduledLevels);
    List<ArrowPath> best = const [];
    var bestScore = double.negativeInfinity;
    for (var attempt = 0; attempt < 4; attempt++) {
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

    // For each empty cell: how many currently free arrows would be trapped
    // by putting something there.
    var laneHits = <Cell, int>{};

    void place(List<Cell> cells) {
      final arrow = ArrowPath(id: arrows.length, cells: cells);
      board.add(arrow);
      arrows.add(arrow);
      filled += cells.length;
      if (config.blockLanes > 0) laneHits = _freeLaneHits(board);
    }

    Cell randomCell() =>
        Cell(rng.nextInt(config.rows), rng.nextInt(config.cols));

    // Random placement.
    var failures = 0;
    while (filled < target && failures < totalCells * 20) {
      // Early arrows (removed last) go deep inside the board; the outer
      // ring is left for the arrows that will leave first.
      var head = randomCell();
      if (laneHits.isNotEmpty && rng.nextDouble() < config.blockLanes) {
        // Trap a free arrow: sit in the lane cell that traps the most.
        final most = laneHits.values.reduce(max);
        final best = [
          for (final e in laneHits.entries)
            if (e.value == most) e.key,
        ];
        head = best[rng.nextInt(best.length)];
      } else if (filled < target * .5) {
        for (var i = 0; i < 3; i++) {
          final other = randomCell();
          if (_depth(config, other) > _depth(config, head)) head = other;
        }
      }
      final dir = rng.nextDouble() < config.aimAcross
          ? _longestLane(board, head) ?? Dir.values[rng.nextInt(4)]
          : Dir.values[rng.nextInt(4)];
      final cells = _grow(board, rng, config, head, dir, laneHits);
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
      if (config.blockLanes > 0) {
        // Holes inside other arrows' lanes first: they make traps.
        empty.sort((a, b) => (laneHits[b] ?? 0).compareTo(laneHits[a] ?? 0));
      }
      for (final start in empty) {
        if (filled >= target) break;
        if (!board.isEmpty(start)) continue;
        final cells = _growFromTail(board, rng, config, start, laneHits);
        if (cells != null) place(cells);
      }
    }

    // Tutorial levels keep their short arrows.
    if (config.fillHoles) {
      _extendTails(
        board,
        arrows,
        rng,
        config.maxLength + 4,
        trapFirst: config.blockLanes > 0,
      );
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
    int maxLength, {
    bool trapFirst = false,
  }) {
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
    var hits = <Cell, int>{};
    while (changed) {
      changed = false;
      if (trapFirst) hits = _freeLaneHits(board);
      final order = [for (var k = 0; k < arrows.length; k++) k]..shuffle(rng);
      for (final k in order) {
        final a = arrows[k];
        if (a.length >= maxLength) continue;
        final dirs = [...Dir.values]..shuffle(rng);
        if (trapFirst) {
          // Growing into a free arrow's lane traps it.
          dirs.sort((x, y) =>
              (hits[a.tail.step(y)] ?? 0).compareTo(hits[a.tail.step(x)] ?? 0));
        }
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

  /// For every empty cell, the number of arrows that can escape right now
  /// whose escape lane runs through it.
  static Map<Cell, int> _freeLaneHits(PuzzleBoard board) {
    final hits = <Cell, int>{};
    for (final a in board.arrows) {
      final lane = <Cell>[];
      var c = a.head.step(a.direction);
      var clear = true;
      while (board.inBounds(c)) {
        if (!board.isEmpty(c)) {
          clear = false;
          break;
        }
        lane.add(c);
        c = c.step(a.direction);
      }
      if (!clear) continue;
      for (final cell in lane) {
        hits[cell] = (hits[cell] ?? 0) + 1;
      }
    }
    return hits;
  }

  /// Picks one of [options] (steps from [from]); with probability
  /// [LevelConfig.blockLanes] it prefers a step onto another arrow's lane.
  static Dir _preferLanes(
    List<Dir> options,
    Cell from,
    Random rng,
    LevelConfig config,
    Map<Cell, int> laneHits,
  ) {
    if (options.length > 1 && rng.nextDouble() < config.blockLanes) {
      final onLane = [
        for (final d in options)
          if ((laneHits[from.step(d)] ?? 0) > 0) d,
      ];
      if (onLane.isNotEmpty) return onLane[rng.nextInt(onLane.length)];
    }
    return options[rng.nextInt(options.length)];
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
    Map<Cell, int> laneHits,
  ) {
    final path = [start];
    // Hard levels walk further before taking an exit, so the new arrow
    // covers more lane cells and is less often a quick free move.
    final minExit = 3 + (config.blockLanes * 3).round();
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
            (_clearLane(board, next, d, body)?.length ?? -1) >=
                config.minLane) {
          exit = d;
          break;
        }
      }
      if (exit != null && (path.length + 1 >= minExit || rng.nextBool())) {
        path.add(path.last.step(exit));
        return path;
      }
      final keep = heading != null &&
          options.contains(heading) &&
          rng.nextDouble() < config.straightness;
      heading = keep
          ? heading
          : _preferLanes(options, path.last, rng, config, laneHits);
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
    Map<Cell, int> laneHits,
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
    if (lane.length < config.minLane) return null;

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
      heading = _preferLanes(options, path.last, rng, config, laneHits);
      final next = path.last.step(heading);
      path.add(next);
      body.add(next);
    }

    return path.reversed.toList();
  }
}
