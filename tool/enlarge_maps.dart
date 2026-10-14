// dart run tool/enlarge_maps.dart
// Expands campaign grids from level 76 by at least 50%, regenerates puzzles,
// and restores a difficulty peak every fifth level within each 75-level slot.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:arrow_puzzle/engine/board_shape.dart';
import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/level_codec.dart';

void main() {
  final file = File('assets/levels/levels.json');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = (data['levels'] as List).cast<Map<String, dynamic>>();
  if (entries.length != 225 ||
      entries.any((l) => l.containsKey('originalDots'))) {
    throw StateError('Expected the original curated 225-level campaign.');
  }
  for (var i = 75; i < entries.length; i++) {
    final original = LevelCodec.decodeLevel(entries[i]);
    final dots = original.shape.cells.length;
    final source = entries[i]['sourceLevel'] as int;
    final d = LevelGenerator.difficultyForLevel(source);
    final base = LevelGenerator.configAt(d, cols: original.cols);
    final LevelConfig config;
    if (original.shape case final CubeShape cube) {
      config = LevelGenerator.cubeConfig((cube.n * math.sqrt(1.5)).ceil(), d,
          allSides: cube.allSides);
    } else {
      final cols = (original.cols * math.sqrt(1.5)).ceil();
      final rows = (dots * 1.5 / cols).ceil();
      config = LevelConfig(
          rows: rows,
          cols: cols,
          minLength: base.minLength,
          maxLength: base.maxLength,
          fill: base.fill,
          straightness: base.straightness,
          aimAcross: base.aimAcross,
          fillHoles: true,
          blockLanes: base.blockLanes,
          minLane: base.minLane);
    }
    Map<String, dynamic>? best;
    var bestScore = double.negativeInfinity;
    for (var attempt = 0; attempt < 24; attempt++) {
      final arrows =
          LevelGenerator.build(config, source * 7919 + attempt * 104729 + 53);
      final level = LevelGenerator.toLevel(i + 1, config, arrows);
      final board = PuzzleBoard.forLevel(level);
      final stats = board.analyze();
      if (!stats.solvable) continue;
      if (config.shape case final CubeShape cube) {
        final cross = arrows.where((a) {
          final r = board.evaluate(a);
          return r is Blocked && cube.faceOf(r.hitCell) != cube.faceOf(a.head);
        }).length;
        if (cross < 2) continue;
        if (cube.allSides) {
          final perFace = List.filled(6, 0);
          for (final a in arrows) {
            perFace[cube.faceOf(a.head)]++;
          }
          if (perFace.any((n) => n < 2)) continue;
        }
      }
      if (stats.score > bestScore) {
        bestScore = stats.score;
        best = {
          ...LevelCodec.encodeLevel(level),
          'sourceLevel': source,
          'originalDots': dots,
          's': {
            'arrows': stats.arrows,
            'free': stats.initialFree,
            'layers': stats.layers,
            'score': double.parse(stats.score.toStringAsFixed(2))
          }
        };
      }
      if (attempt >= 3 && best != null) break;
    }
    if (best == null) {
      throw StateError('Unable to generate source level $source');
    }
    entries[i] = best;
    stdout.writeln(
        'Expanded ${i + 1}: $dots -> ${config.shape.cells.length} dots');
  }
  for (var slot = 1; slot < 3; slot++) {
    final ranked = entries.sublist(slot * 75, (slot + 1) * 75)
      ..sort(
          (a, b) => (a['s']['score'] as num).compareTo(b['s']['score'] as num));
    for (var block = 0; block < 15; block++) {
      final group = [
        ...ranked.sublist(block * 4, block * 4 + 4),
        ranked[60 + block]
      ];
      for (var j = 0; j < 5; j++) {
        final index = slot * 75 + block * 5 + j;
        entries[index] = group[j]..['n'] = index + 1;
      }
    }
  }
  file.writeAsStringSync('${jsonEncode(data)}\n');
}
