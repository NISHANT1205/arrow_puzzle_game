// ignore_for_file: avoid_print

// Prints board size, arrow count and fill ratio for a range of levels.
//
//   dart run tool/level_stats.dart [from] [to]

import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';

void main(List<String> args) {
  final from = args.isNotEmpty ? int.parse(args[0]) : 1;
  final to = args.length > 1 ? int.parse(args[1]) : 100;
  for (var n = from; n <= to; n++) {
    final sw = Stopwatch()..start();
    final level = LevelGenerator.generate(n);
    final ms = sw.elapsedMilliseconds;
    final cells = level.arrows.fold<int>(0, (s, a) => s + a.length);
    final board =
        PuzzleBoard(rows: level.rows, cols: level.cols, arrows: level.arrows);
    final solvable = board.solve() != null;
    final fill = cells / (level.rows * level.cols);
    print('level $n: ${level.cols}x${level.rows} arrows=${level.arrows.length} '
        'fill=${(fill * 100).toStringAsFixed(0)}% solvable=$solvable ${ms}ms');
  }
}
