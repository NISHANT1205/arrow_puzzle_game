import 'dart:math';

import 'game_state.dart';
import 'level.dart';
import 'solver.dart';

/// Builds solvable levels by construction.
///
/// 1. Park vehicles one at a time; each new vehicle must have a clear road
///    out past the vehicles already parked. Removing vehicles newest-first
///    therefore always works, so the lot can never jam completely.
/// 2. Play a random geometric exit order (any vehicle with a clear road).
/// 3. Line passengers up in exactly that order, then scramble them with
///    random swaps, keeping a swap only if that order still wins without
///    needing more station bays than the difficulty budget allows.
/// 4. Reject levels a casual player wins too easily (or almost never), and
///    confirm the rest with the independent [Solver].
class LevelGenerator {
  static const maxColors = 8;

  final int number;
  final Random rng;

  LevelGenerator(this.number, int seed) : rng = Random(seed);

  bool get _isBoss => number % 10 == 0;
  bool get _isBreather => number % 10 == 1 && number > 20;

  int get _cols => number <= 10 ? 6 : (number <= 40 ? 7 : 8);
  int get _rows =>
      number <= 10 ? 7 : (number <= 40 ? 9 : (number <= 120 ? 10 : 11));

  double get _density {
    var d = 0.32 + min(number, 200) / 200 * 0.4;
    if (_isBoss) d += 0.06;
    if (_isBreather) d -= 0.12;
    return d.clamp(0.25, 0.8);
  }

  int get _colors {
    int c;
    if (number <= 3) {
      c = 2;
    } else if (number <= 15) {
      c = 3;
    } else if (number <= 40) {
      c = 4;
    } else if (number <= 90) {
      c = 5;
    } else if (number <= 150) {
      c = 6;
    } else if (number <= 210) {
      c = 7;
    } else {
      c = 8;
    }
    if (_isBreather) c = max(2, c - 1);
    return c;
  }

  /// Station bays the reference order may use at once.
  int get _bayBudget {
    if (number <= 5) return 2;
    if (number <= 25 || _isBreather) return 3;
    if (number <= 100) return 4;
    return 5;
  }

  int get _swapAttempts {
    if (number <= 2) return 0;
    if (_isBreather) return 30;
    return min(80 + number * 8, 2000) + (_isBoss ? 400 : 0);
  }

  double get _maxCasualWinRate {
    if (number <= 12 || _isBreather) return 1.0;
    var r = 1.0 - (number - 12) / 238 * 0.65;
    if (_isBoss) r -= 0.15;
    return r;
  }

  VehicleKind _kind() {
    final r = rng.nextDouble();
    if (number <= 6) return VehicleKind.car;
    if (number <= 15) return r < 0.7 ? VehicleKind.car : VehicleKind.van;
    if (r < 0.5) return VehicleKind.car;
    if (r < 0.8) return VehicleKind.van;
    return VehicleKind.bus;
  }

  LevelDef? tryGenerate() {
    final cols = _cols, rows = _rows;
    final grid = List<int>.filled(cols * rows, -1);
    final placed = <VehicleDef>[];
    final target = (cols * rows * _density).round();
    var filled = 0;

    bool fits(VehicleDef v) {
      for (final (x, y) in v.cells) {
        if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
        if (grid[y * cols + x] >= 0) return false;
      }
      var x = v.x + v.dir.dx, y = v.y + v.dir.dy;
      while (x >= 0 && y >= 0 && x < cols && y < rows) {
        if (grid[y * cols + x] >= 0) return false;
        x += v.dir.dx;
        y += v.dir.dy;
      }
      return true;
    }

    // How many parked vehicles this one would block.
    int blocks(VehicleDef v) {
      final mine = v.cells.toSet();
      var n = 0;
      for (final o in placed) {
        var x = o.x + o.dir.dx, y = o.y + o.dir.dy;
        while (x >= 0 && y >= 0 && x < cols && y < rows) {
          if (mine.contains((x, y))) {
            n++;
            break;
          }
          x += o.dir.dx;
          y += o.dir.dy;
        }
      }
      return n;
    }

    var misses = 0;
    while (filled < target && misses < 60) {
      VehicleDef? best;
      var bestScore = -1.0;
      for (var t = 0; t < 40; t++) {
        final kind = _kind();
        final dir = Dir.values[rng.nextInt(4)];
        final v = VehicleDef(
          rng.nextInt(cols),
          rng.nextInt(rows),
          dir,
          kind,
          0,
        );
        if (!fits(v)) continue;
        final s = blocks(v) + rng.nextDouble() * 1.5;
        if (s > bestScore) {
          bestScore = s;
          best = v;
        }
      }
      if (best == null) {
        misses++;
        continue;
      }
      for (final (x, y) in best.cells) {
        grid[y * cols + x] = placed.length;
      }
      placed.add(best);
      filled += best.length;
    }
    if (placed.length < 3) return null;

    // Colours: every colour used at least once.
    final colorCount = min(_colors, placed.length);
    final palette = List.generate(maxColors, (i) => i)..shuffle(rng);
    final used = palette.take(colorCount).toList();
    final colors = [
      for (var i = 0; i < placed.length; i++)
        i < colorCount ? used[i] : used[rng.nextInt(colorCount)],
    ]..shuffle(rng);
    final vehicles = [
      for (var i = 0; i < placed.length; i++)
        VehicleDef(
          placed[i].x,
          placed[i].y,
          placed[i].dir,
          placed[i].kind,
          colors[i],
        ),
    ];

    final order = _randomOrder(cols, rows, vehicles);
    final queue = <int>[
      for (final i in order)
        for (var s = 0; s < vehicles[i].seats; s++) vehicles[i].color,
    ];

    LevelDef build() => LevelDef(
      number: number,
      cols: cols,
      rows: rows,
      slots: 5,
      vehicles: vehicles,
      queue: List.of(queue),
      solution: order,
    );

    if (_peakBays(build(), order) == null) return null;
    final budget = _bayBudget;
    for (var a = 0; a < _swapAttempts; a++) {
      final i = rng.nextInt(queue.length), j = rng.nextInt(queue.length);
      if (queue[i] == queue[j]) continue;
      final t = queue[i];
      queue[i] = queue[j];
      queue[j] = t;
      final peak = _peakBays(build(), order);
      if (peak == null || peak > budget) {
        queue[j] = queue[i];
        queue[i] = t;
      }
    }

    final level = build();
    final rate = casualWinRate(level, Random(number), 60);
    if (rate > _maxCasualWinRate || rate < 0.05) return null;
    if (Solver(nodeLimit: 60000).solve(GameState.initial(level)) == null) {
      return null;
    }
    return level;
  }

  /// Any vehicle with a clear road may leave; geometry only.
  List<int> _randomOrder(int cols, int rows, List<VehicleDef> vehicles) {
    final probe = GameState.initial(
      LevelDef(
        number: number,
        cols: cols,
        rows: rows,
        slots: 1,
        vehicles: vehicles,
        queue: const [],
        solution: const [],
      ),
    );
    final order = <int>[];
    while (order.length < vehicles.length) {
      final free = [
        for (var i = 0; i < vehicles.length; i++)
          if (probe.loc[i] == VehicleLoc.lot && probe.blocker(i) == null) i,
      ];
      final m = free[rng.nextInt(free.length)];
      for (final (x, y) in vehicles[m].cells) {
        probe.grid[y * cols + x] = -1;
      }
      probe.loc[m] = VehicleLoc.gone;
      order.add(m);
    }
    return order;
  }

  /// Replays [order]; returns the most bays in use at once, or null on failure.
  static int? _peakBays(LevelDef level, List<int> order) {
    final g = GameState.initial(level);
    var peak = 0;
    for (final m in order) {
      if (g.tap(m) != TapResult.parked) return null;
      peak = max(
        peak,
        g.bays.where((b) => b != null).length + g.lastDeparted.length,
      );
    }
    return g.isWon ? peak : null;
  }

  /// Win rate of a player who taps a vehicle the front passenger can board
  /// when one is free, and otherwise any free vehicle at random.
  static double casualWinRate(LevelDef level, Random rng, int trials) {
    var wins = 0;
    for (var t = 0; t < trials; t++) {
      final g = GameState.initial(level);
      while (!g.isWon) {
        final moves = g.legalMoves();
        if (moves.isEmpty) break;
        final want = g.front < level.queue.length ? level.queue[g.front] : -1;
        final good = moves
            .where((m) => level.vehicles[m].color == want)
            .toList();
        final pool = good.isNotEmpty ? good : moves;
        g.tap(pool[rng.nextInt(pool.length)]);
      }
      if (g.isWon) wins++;
    }
    return wins / trials;
  }

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
