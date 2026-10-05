// ignore_for_file: avoid_print

// Builds the bundled levels: assets/levels/levels.json.
//
//   dart run tool/build_levels.dart [count]
//
// Every level is checked with the solver and must be strictly harder than the
// one before it (see BoardStats.score): more arrow to trace, longer chains of
// ordered moves, fewer safe first moves.
//
// Board size and generator knobs follow LevelGenerator's schedule: gentle up
// to level 100, then a steep climb (bigger boards, traps in escape lanes,
// longer arrows) to level 200, and the biggest board with full-strength
// traps from there to 300. Levels sharing a board size share a pool of
// boards; the builder sorts the pool by score and hands out evenly spaced
// boards that beat the previous level, staying in the lower part of the pool
// so the next group still has harder boards to offer.
//
// A second pass turns every 5th level from 100 on into a 3D cube level (see
// CubeShape) when a cube board scores between the level before and the level
// after it, so the "always harder" rule still holds. From level 150 the
// cubes carry arrows on all six sides.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arrow_puzzle/engine/board_shape.dart';
import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/arrow_path.dart';
import 'package:arrow_puzzle/models/level.dart';
import 'package:arrow_puzzle/models/level_codec.dart';

/// Each level must beat the previous score by at least this factor.
const double minStep = 1.003;

/// Boards built per board size.
const int poolSize = 160;

typedef Option = ({
  LevelConfig config,
  List<ArrowPath> arrows,
  BoardStats stats
});

void main(List<String> args) {
  final count = args.isNotEmpty ? int.parse(args[0]) : 300;
  final levels = <Map<String, dynamic>>[];
  final scores = <double>[];
  var cubes = 0;
  var previousScore = 0.0;
  final sw = Stopwatch()..start();
  if (count != LevelGenerator.scheduledLevels) {
    throw ArgumentError('the difficulty schedule is laid out for '
        '${LevelGenerator.scheduledLevels} levels');
  }
  // Consecutive levels with the same board size share one pool of boards.
  final groups = <List<int>>[];
  for (var n = 1; n <= count; n++) {
    final cols = LevelGenerator.colsForLevel(n);
    if (groups.isEmpty || groups.last.first != cols) groups.add([cols]);
    groups.last.add(n);
  }

  for (var g = 0; g < groups.length; g++) {
    final group = groups[g].sublist(1);
    final first = group.first;
    final wanted = group.length;
    final isLast = g == groups.length - 1;
    // The knobs of the middle level stand for the whole group; the biggest
    // board uses the hardest knobs and a bigger pool for its 100 levels.
    final config = LevelGenerator.configForLevel(
      isLast ? group.last : group[wanted ~/ 2],
    );
    final size = g;

    List<Option>? picked;
    for (var poolTries = isLast ? poolSize * 4 : poolSize;
        picked == null;
        poolTries *= 2) {
      if (poolTries > poolSize * 16) {
        throw StateError('levels $first-${group.last}: ran out of harder '
            'boards');
      }
      picked = _pick(config, size, poolTries, previousScore, wanted, isLast);
    }

    for (var k = 0; k < wanted; k++) {
      final n = first + k;
      final chosen = picked[k];
      final level = LevelGenerator.toLevel(n, chosen.config, chosen.arrows);
      // Re-check the shipped form of the level from scratch.
      final check = PuzzleBoard.forLevel(level).analyze();
      if (!check.solvable) throw StateError('level $n is not solvable');
      if (check.score < previousScore * minStep) {
        throw StateError('level $n is not harder than level ${n - 1}');
      }
      levels.add(_entry(level, check));
      scores.add(check.score);
      previousScore = check.score;
    }
  }

  // Second pass: turn every 5th level from 100 on into a 3D cube level,
  // when a cube fits between its neighbours' scores (harder than the level
  // before, easier than the level after). From level 150 the cubes have
  // arrows on all six sides.
  final cubePools = <String, List<Option>>{};
  for (var n = firstCubeLevel; n <= count; n += cubeEvery) {
    final allSides = n >= allSidesFrom;
    final low = scores[n - 2] * minStep;
    final high = n == count ? double.infinity : scores[n] / minStep;
    final d = LevelGenerator.difficultyForLevel(n);
    Option? best;
    final (minSize, maxSize) =
        allSides ? (minAllSides, maxAllSides) : (minCube, maxCube);
    for (var size = minSize; size <= maxSize; size++) {
      final key = '$size@${(d * 10).round()}${allSides ? 'all' : ''}';
      final pool = cubePools[key] ??= _cubePool(size, d, allSides);
      for (final option in pool) {
        final score = option.stats.score;
        if (score < low || score > high) continue;
        // Prefer the smallest cube that fits: bigger cells, easier to read
        // on a phone.
        if (best == null ||
            option.config.cols < best.config.cols ||
            (option.config.cols == best.config.cols &&
                score < best.stats.score)) {
          best = option;
        }
      }
    }
    if (best == null) {
      print('level $n: no cube fits, stays flat');
      continue;
    }
    // Don't hand the same board out twice.
    for (final pool in cubePools.values) {
      pool.remove(best);
    }
    final level = LevelGenerator.toLevel(n, best.config, best.arrows);
    final check = PuzzleBoard.forLevel(level).analyze();
    if (!check.solvable || check.score < low || check.score > high) {
      throw StateError('cube level $n does not fit');
    }
    levels[n - 1] = _entry(level, check);
    scores[n - 1] = check.score;
    cubes++;
  }

  for (var i = 0; i < levels.length; i++) {
    final l = levels[i];
    final shape = l['shape'] == null ? '' : ' CUBE';
    print('level ${i + 1} ${l['c']}x${l['r']}$shape ${l['s']}');
  }
  print('$cubes cube levels');

  final file = File('assets/levels/levels.json');
  file.writeAsStringSync(jsonEncode({'version': 1, 'levels': levels}));
  print('wrote ${levels.length} levels to ${file.path} '
      '(${(file.lengthSync() / 1024).round()} KB) in ${sw.elapsed.inSeconds}s');
}

/// Cube levels: every [cubeEvery]th level from [firstCubeLevel]. Three-face
/// cubes have edges of [minCube]-[maxCube] cells; from [allSidesFrom] on,
/// cubes have arrows on all six sides and edges of
/// [minAllSides]-[maxAllSides] cells.
const int firstCubeLevel = 100;
const int cubeEvery = 5;
const int allSidesFrom = 150;
const int minCube = 6;
const int maxCube = 16;
const int minAllSides = 4;
const int maxAllSides = 12;

/// Every side of an all-sides cube holds at least this many arrows.
const int minArrowsPerFace = 2;
const int minCrossFace = 2;

/// A pool of cube boards of edge [size] at difficulty [d]. Only boards
/// where at the start at least [minCrossFace] arrows are blocked by an arrow
/// on another face are kept, so the 3D rule matters; all-sides cubes also
/// need [minArrowsPerFace] arrows on every side.
List<Option> _cubePool(int size, double d, bool allSides) {
  final config = LevelGenerator.cubeConfig(size, d, allSides: allSides);
  final shape = config.shape as CubeShape;
  final pool = <Option>[];
  for (var i = 0; i < 120; i++) {
    final arrows = LevelGenerator.build(
      config,
      size * 7000003 + (d * 1000).round() * 31 + i * 7919 + (allSides ? 1 : 0),
    );
    final stats = LevelGenerator.difficultyOf(config, arrows);
    if (!stats.solvable) throw StateError('cube $size board $i stuck');
    final board = PuzzleBoard(
      rows: config.rows,
      cols: config.cols,
      arrows: arrows,
      shape: shape,
    );
    final crossFace = arrows.where((a) {
      final r = board.evaluate(a);
      return r is Blocked && shape.faceOf(r.hitCell) != shape.faceOf(a.head);
    }).length;
    if (crossFace < minCrossFace) continue;
    if (allSides) {
      final perFace = List.filled(shape.faceCount, 0);
      for (final a in arrows) {
        perFace[shape.faceOf(a.head)]++;
      }
      if (perFace.any((k) => k < minArrowsPerFace)) continue;
    }
    pool.add((config: config, arrows: arrows, stats: stats));
  }
  return pool;
}

Map<String, dynamic> _entry(Level level, BoardStats check) => {
      ...LevelCodec.encodeLevel(level),
      's': {
        'arrows': check.arrows,
        'free': check.initialFree,
        'layers': check.layers,
        'score': double.parse(check.score.toStringAsFixed(2)),
      },
    };

/// Builds [poolTries] boards for [config] and picks [wanted] of them in
/// strictly rising score, all harder than [previousScore]. Returns null when
/// the pool doesn't have enough harder boards.
List<Option>? _pick(
  LevelConfig config,
  int size,
  int poolTries,
  double previousScore,
  int wanted,
  bool isLast,
) {
  final pool = <Option>[];
  for (var i = 0; i < poolTries; i++) {
    final arrows = LevelGenerator.build(config, size * 1000003 + i * 7919);
    final stats = LevelGenerator.difficultyOf(config, arrows);
    if (!stats.solvable) {
      throw StateError('size ${config.cols} board $i is not solvable');
    }
    pool.add((config: config, arrows: arrows, stats: stats));
  }
  pool.sort((a, b) => a.stats.score.compareTo(b.stats.score));

  final eligible = [
    for (final o in pool)
      if (o.stats.score >= previousScore * minStep) o,
  ];
  // Use the lower part of what is left, so the next size still has harder
  // boards to offer. The biggest size may use everything.
  final span = isLast
      ? eligible.length
      : max(wanted, (eligible.length * .6).round()).clamp(0, eligible.length);

  final picked = <Option>[];
  var floor = previousScore * minStep;
  var from = 0;
  for (var k = 0; k < wanted; k++) {
    final target = max(from, (k * (span - 1) / max(1, wanted - 1)).round());
    Option? choice;
    for (var i = target; i < eligible.length; i++) {
      if (eligible[i].stats.score >= floor) {
        choice = eligible[i];
        from = i + 1;
        break;
      }
    }
    if (choice == null) return null;
    picked.add(choice);
    floor = choice.stats.score * minStep;
  }
  return picked;
}
