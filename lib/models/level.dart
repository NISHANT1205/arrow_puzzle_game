// lib/models/level.dart

import '../engine/board_shape.dart';
import 'arrow_path.dart';

/// A puzzle: a rectangular dot grid holding a set of arrows.
class Level {
  const Level({
    required this.number,
    required this.rows,
    required this.cols,
    required this.arrows,
    BoardShape? shape,
  }) : _shape = shape;

  final int number;
  final int rows;
  final int cols;
  final List<ArrowPath> arrows;
  final BoardShape? _shape;

  /// The surface the arrows sit on: a flat rectangle unless stated.
  BoardShape get shape => _shape ?? RectShape(rows, cols);

  bool get isCube => shape is CubeShape;

  Map<String, dynamic> toJson() => {
        'number': number,
        'rows': rows,
        'cols': cols,
        'arrows': [for (final a in arrows) a.toJson()],
        'shape': shape.toJson(),
      };

  factory Level.fromJson(Map<String, dynamic> json) => Level(
        number: json['number'] as int,
        rows: json['rows'] as int,
        cols: json['cols'] as int,
        arrows: [
          for (final a in json['arrows'] as List<dynamic>)
            ArrowPath.fromJson(a as Map<String, dynamic>),
        ],
        shape: BoardShape.fromJson(
          json['shape'] as Map<String, dynamic>?,
          json['rows'] as int,
          json['cols'] as int,
        ),
      );

  @override
  String toString() => 'Level $number (${cols}x$rows, ${arrows.length} arrows)';
}
