// ignore_for_file: avoid_print

// Checks and prints difficulty numbers for a range of levels.
//
//   dart run tool/level_stats.dart [from] [to]

import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';

void main(List<String> args) {
  final from = args.isNotEmpty ? int.parse(args[0]) : 1;
  final to = args.length > 1 ? int.parse(args[1]) : 100;
  var unsolvable = 0;
  var slowest = 0;
  for (var n = from; n <= to; n++) {
    final sw = Stopwatch()..start();
    final level = LevelGenerator.generate(n);
    final ms = sw.elapsedMilliseconds;
    if (ms > slowest) slowest = ms;
    final cells = level.arrows.fold<int>(0, (s, a) => s + a.length);
    final stats =
        PuzzleBoard(rows: level.rows, cols: level.cols, arrows: level.arrows)
            .analyze();
    if (!stats.solvable) unsolvable++;
    final fill = cells / (level.rows * level.cols);
    print('level $n [${LevelGenerator.tierFor(n).label}] '
        '${level.cols}x${level.rows} fill=${(fill * 100).round()}% '
        '$stats ${ms}ms');
  }
  print('checked ${to - from + 1} levels: unsolvable=$unsolvable '
      'slowest=${slowest}ms');
}
