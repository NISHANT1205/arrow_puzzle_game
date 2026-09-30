// lib/models/level_codec.dart
//
// Compact text format for bundled levels. An arrow is written as its tail
// cell followed by one letter per step towards the head:
//
//   "5,0:UUR"  = tail (5,0), then up, up, right -> head (3,1) pointing right
//
// A level is {"n": number, "r": rows, "c": cols, "a": [arrows...]},
// plus "shape": {"t": "cube", "n": size} for 3D cube levels.

import '../engine/board_shape.dart';
import 'arrow_path.dart';
import 'level.dart';

class LevelCodec {
  const LevelCodec._();

  static const _letters = {
    Dir.up: 'U',
    Dir.down: 'D',
    Dir.left: 'L',
    Dir.right: 'R',
  };

  static String encodeArrow(ArrowPath arrow) {
    final moves = StringBuffer();
    for (var i = 1; i < arrow.cells.length; i++) {
      moves.write(_letters[Dir.between(arrow.cells[i - 1], arrow.cells[i])]);
    }
    return '${arrow.tail.row},${arrow.tail.col}:$moves';
  }

  static ArrowPath decodeArrow(int id, String text) {
    final colon = text.indexOf(':');
    final comma = text.indexOf(',');
    var cell = Cell(
      int.parse(text.substring(0, comma)),
      int.parse(text.substring(comma + 1, colon)),
    );
    final cells = [cell];
    for (final letter in text.substring(colon + 1).split('')) {
      final dir = _letters.entries.firstWhere((e) => e.value == letter).key;
      cell = cell.step(dir);
      cells.add(cell);
    }
    return ArrowPath(id: id, cells: cells);
  }

  static Map<String, dynamic> encodeLevel(Level level) => {
        'n': level.number,
        'r': level.rows,
        'c': level.cols,
        'a': [for (final a in level.arrows) encodeArrow(a)],
        if (level.isCube) 'shape': level.shape.toJson(),
      };

  static Level decodeLevel(Map<String, dynamic> json) {
    final arrows = json['a'] as List<dynamic>;
    final rows = json['r'] as int;
    final cols = json['c'] as int;
    return Level(
      number: json['n'] as int,
      rows: rows,
      cols: cols,
      shape: BoardShape.fromJson(
        json['shape'] as Map<String, dynamic>?,
        rows,
        cols,
      ),
      arrows: [
        for (var i = 0; i < arrows.length; i++)
          decodeArrow(i, arrows[i] as String),
      ],
    );
  }
}
