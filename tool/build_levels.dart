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

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/arrow_path.dart';
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
      final check =
          PuzzleBoard(rows: level.rows, cols: level.cols, arrows: level.arrows)
              .analyze();
      if (!check.solvable) throw StateError('level $n is not solvable');
      if (check.score < previousScore * minStep) {
        throw StateError('level $n is not harder than level ${n - 1}');
      }
      levels.add({
        ...LevelCodec.encodeLevel(level),
        's': {
          'arrows': check.arrows,
          'free': check.initialFree,
          'layers': check.layers,
          'score': double.parse(check.score.toStringAsFixed(2)),
        },
      });
      previousScore = check.score;
      print('level $n ${level.cols}x${level.rows} $check');
    }
  }

  final file = File('assets/levels/levels.json');
  file.writeAsStringSync(jsonEncode({'version': 1, 'levels': levels}));
  print('wrote ${levels.length} levels to ${file.path} '
      '(${(file.lengthSync() / 1024).round()} KB) in ${sw.elapsed.inSeconds}s');
}

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
