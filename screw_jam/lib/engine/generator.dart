import 'dart:math';

import 'game_state.dart';
import 'level.dart';
import 'solver.dart';

/// Builds solvable levels by construction.
///
/// 1. Stack random plates and pin each with screws.
/// 2. Play a random "unscrew anything that is free" order to the end; this
///    always succeeds because the top plate is never covered.
/// 3. Colour screws along that order so the order fills the boxes exactly,
///    then scramble colours with random swaps, keeping only swaps after which
///    the order still wins inside the tray limit.
/// 4. Confirm with the independent [Solver] from the starting position.
class LevelGenerator {
  static const maxColors = 9;

  static const _shapes = [
    [2, 1], [1, 2], [3, 1], [1, 3], [2, 2], [4, 1], [1, 4], //
    [3, 2], [2, 3], [3, 3], [5, 1], [1, 5], [4, 2], [2, 4],
  ];

  final int number;
  final Random rng;

  LevelGenerator(this.number, int seed) : rng = Random(seed);

  // Difficulty curve ------------------------------------------------------

  int get _cols => number <= 10 ? 5 : (number <= 40 ? 6 : 7);
  int get _rows => number <= 10 ? 6 : (number <= 40 ? 8 : 10);

  bool get _isBoss => number % 10 == 0;
  bool get _isBreather => number % 10 == 1 && number > 20;

  int get _plates {
    if (number <= 3) return 1 + number;
    var p = 4 + (number * 16 / 250).floor() + rng.nextInt(2);
    if (_isBoss) p += 2;
    if (_isBreather) p -= 3;
    return p.clamp(3, 22);
  }

  int get _colors {
    int c;
    if (number <= 5) {
      c = 2;
    } else if (number <= 20) {
      c = 3;
    } else if (number <= 50) {
      c = 4;
    } else if (number <= 100) {
      c = 5;
    } else if (number <= 150) {
      c = 6;
    } else if (number <= 200) {
      c = 7;
    } else {
      c = 8;
    }
    if (_isBreather) c = max(2, c - 1);
    return c;
  }

  int get _maxScrewsPerPlate => number <= 8 ? 2 : (number <= 40 ? 3 : 4);

  /// Levels below this many screws are rejected and re-rolled.
  int get _minScrews {
    if (number <= 2) return 3;
    if (number <= 10) return 6;
    var m = 9 + (number * 30 / 250).floor();
    if (_isBoss) m += 6;
    if (_isBreather) m -= 6;
    return m;
  }

  /// Tray slots the reference order may use at most.
  int get _trayBudget {
    if (number <= 5) return 1;
    if (number <= 30) return 3;
    if (_isBreather) return 3;
    if (number <= 120) return 4;
    return 5;
  }

  int get _swapAttempts {
    if (number <= 2) return 0;
    if (_isBreather) return 20;
    return min(60 + number * 6, 1500) + (_isBoss ? 300 : 0);
  }

  // Generation -------------------------------------------------------------

  LevelDef? tryGenerate() {
    final cols = _cols, rows = _rows;
    final plates = <PlateDef>[];
    final screwCells = <int>{};
    final screwPlate = <List<int>>[]; // [x, y, plate]

    final plateCount = _plates;
    for (var p = 0; p < plateCount; p++) {
      final plate = _placePlate(cols, rows, plates);
      if (plate == null) continue;
      final cells = _candidateCells(plate)..shuffle(rng);
      final want = min(cells.length, 2 + rng.nextInt(_maxScrewsPerPlate - 1));
      final chosen = <List<int>>[];
      for (final c in cells) {
        if (chosen.length >= want) break;
        final key = c[1] * cols + c[0];
        if (screwCells.contains(key)) continue;
        // Keep screws of one plate apart so they read clearly.
        if (chosen.any((o) => (o[0] - c[0]).abs() + (o[1] - c[1]).abs() < 2)) {
          continue;
        }
        chosen.add(c);
      }
      if (chosen.isEmpty) continue;
      final idx = plates.length;
      plates.add(plate);
      for (final c in chosen) {
        screwCells.add(c[1] * cols + c[0]);
        screwPlate.add([c[0], c[1], idx]);
      }
    }
    if (plates.length < 2) return null;

    // Total screws must fill whole boxes.
    while (screwPlate.length % 3 != 0) {
      final counts = <int, int>{};
      for (final s in screwPlate) {
        counts[s[2]] = (counts[s[2]] ?? 0) + 1;
      }
      final removable = [
        for (var i = 0; i < screwPlate.length; i++)
          if (counts[screwPlate[i][2]]! > 1) i,
      ];
      if (removable.isEmpty) return null;
      screwPlate.removeAt(removable[rng.nextInt(removable.length)]);
    }
    if (screwPlate.length < _minScrews) return null;
    final boxCount = screwPlate.length ~/ 3;
    final colorCount = min(_colors, boxCount);
    if (colorCount < 1) return null;

    // Box colour queue: every colour appears, no triple repeats.
    final palette = List.generate(maxColors, (i) => i)..shuffle(rng);
    final used = palette.take(colorCount).toList();
    final boxes = <int>[...used];
    while (boxes.length < boxCount) {
      boxes.add(used[rng.nextInt(used.length)]);
    }
    for (var tries = 0; tries < 50; tries++) {
      boxes.shuffle(rng);
      var ok = true;
      for (var i = 2; i < boxes.length; i++) {
        if (boxes[i] == boxes[i - 1] && boxes[i] == boxes[i - 2]) ok = false;
      }
      if (ok) break;
    }

    // Reference order ignoring colours.
    final colorless = LevelDef(
      number: number,
      cols: cols,
      rows: rows,
      bufferSize: 5,
      activeBoxes: 2,
      plates: plates,
      screws: [for (final s in screwPlate) ScrewDef(s[0], s[1], s[2], 0)],
      boxes: List.filled(boxCount, 0),
      solution: const [],
    );
    final order = _randomOrder(colorless);

    // Order position j feeds box j ~/ 3 when two boxes are open, as long as
    // boxes are consumed in queue order. Start from that zero-tray colouring.
    final colors = List<int>.filled(screwPlate.length, 0);
    for (var j = 0; j < order.length; j++) {
      colors[order[j]] = boxes[j ~/ 3];
    }

    LevelDef build(List<int> c) => LevelDef(
      number: number,
      cols: cols,
      rows: rows,
      bufferSize: 5,
      activeBoxes: 2,
      plates: plates,
      screws: [
        for (var i = 0; i < screwPlate.length; i++)
          ScrewDef(screwPlate[i][0], screwPlate[i][1], screwPlate[i][2], c[i]),
      ],
      boxes: boxes,
      solution: order,
    );

    if (_peakTray(build(colors), order) == null) return null;

    final n = colors.length;
    for (var a = 0; a < _swapAttempts; a++) {
      final i = rng.nextInt(n), j = rng.nextInt(n);
      if (colors[i] == colors[j]) continue;
      final t = colors[i];
      colors[i] = colors[j];
      colors[j] = t;
      final peak = _peakTray(build(colors), order);
      if (peak == null || peak > _trayBudget) {
        colors[j] = colors[i];
        colors[i] = t;
      }
    }

    final level = build(colors);
    final rate = casualWinRate(level, Random(number), 80);
    if (rate > _maxCasualWinRate || rate < 0.05) return null;
    final solved = Solver(nodeLimit: 60000).solve(GameState.initial(level));
    if (solved == null) return null;
    return level;
  }

  /// Upper bound on how often a casual player (who always fills an open box
  /// when possible and otherwise taps a random free screw) should win.
  double get _maxCasualWinRate {
    if (number <= 15 || _isBreather) return 1.0;
    var r = 1.0 - (number - 15) / 235 * 0.6;
    if (_isBoss) r -= 0.15;
    return r;
  }

  /// Fraction of [trials] random casual play-throughs that win.
  static double casualWinRate(LevelDef level, Random rng, int trials) {
    var wins = 0;
    for (var t = 0; t < trials; t++) {
      final g = GameState.initial(level);
      while (!g.isWon) {
        final moves = g.legalMoves();
        if (moves.isEmpty) break;
        final box = moves
            .where((m) => g.destinationOf(m) == TapResult.toBox)
            .toList();
        final pool = box.isNotEmpty ? box : moves;
        g.tap(pool[rng.nextInt(pool.length)]);
      }
      if (g.isWon) wins++;
    }
    return wins / trials;
  }

  /// Replays [order]; returns the highest tray fill, or null if it fails.
  int? _peakTray(LevelDef level, List<int> order) {
    final g = GameState.initial(level);
    var peak = 0;
    for (final m in order) {
      final r = g.tap(m);
      if (r != TapResult.toBox && r != TapResult.toBuffer) return null;
      peak = max(peak, g.buffer.length);
    }
    return g.isWon ? peak : null;
  }

  List<int> _randomOrder(LevelDef level) {
    final g = GameState.initial(level);
    final order = <int>[];
    while (order.length < level.screws.length) {
      final free = [
        for (var i = 0; i < level.screws.length; i++)
          if (g.isFree(i)) i,
      ];
      final m = free[rng.nextInt(free.length)];
      // Bypass colour rules: only geometry matters for the order.
      g.screwLoc[m] = ScrewLocation.box;
      final p = level.screws[m].plate;
      if (--g.plateScrewsLeft[p] == 0) g.plateAlive[p] = false;
      order.add(m);
    }
    return order;
  }

  PlateDef? _placePlate(int cols, int rows, List<PlateDef> existing) {
    PlateDef? best;
    var bestScore = -1.0;
    for (var t = 0; t < 12; t++) {
      final s = _shapes[rng.nextInt(_shapes.length)];
      final w = s[0], h = s[1];
      if (w > cols || h > rows) continue;
      final x = rng.nextInt(cols - w + 1), y = rng.nextInt(rows - h + 1);
      final plate = PlateDef(x, y, w, h);
      var overlap = 0;
      for (final e in existing) {
        final ox = max<int>(0, min(e.x + e.w, x + w) - max(e.x, x));
        final oy = max<int>(0, min(e.y + e.h, y + h) - max(e.y, y));
        overlap += ox * oy;
      }
      // Prefer some overlap, but not burying a plate completely.
      final area = w * h;
      final ratio = existing.isEmpty ? 0.5 : overlap / area;
      final score = (ratio > 0 && ratio < 0.9 ? 1.0 : 0.3) + rng.nextDouble();
      if (score > bestScore) {
        bestScore = score;
        best = plate;
      }
    }
    return best;
  }

  List<List<int>> _candidateCells(PlateDef p) {
    final set = <String, List<int>>{};
    void add(int x, int y) => set['$x,$y'] = [x, y];
    add(p.x, p.y);
    add(p.x + p.w - 1, p.y);
    add(p.x, p.y + p.h - 1);
    add(p.x + p.w - 1, p.y + p.h - 1);
    if (p.w >= 3 || p.h >= 3) add(p.x + (p.w - 1) ~/ 2, p.y + (p.h - 1) ~/ 2);
    if (p.w >= 4 && p.h >= 2) {
      add(p.x + (p.w - 1) ~/ 2, p.y);
      add(p.x + (p.w - 1) ~/ 2, p.y + p.h - 1);
    }
    if (p.h >= 4 && p.w >= 2) {
      add(p.x, p.y + (p.h - 1) ~/ 2);
      add(p.x + p.w - 1, p.y + (p.h - 1) ~/ 2);
    }
    return set.values.toList();
  }

  /// Generates level [number], retrying seeds until one passes every check.
  static LevelDef generate(int number) {
    for (var attempt = 0; attempt < 5000; attempt++) {
      final level = LevelGenerator(
        number,
        number * 7919 + attempt * 104729,
      ).tryGenerate();
      if (level != null) return level;
    }
    throw StateError('Could not generate level $number');
  }
}
