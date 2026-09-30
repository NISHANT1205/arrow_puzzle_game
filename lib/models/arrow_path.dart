// lib/models/arrow_path.dart
//
// Core data types for the snake-arrow puzzle: a grid cell, the four
// directions an arrow head can point, and an arrow whose body is a path of
// orthogonally connected cells ending in a head.

/// One of the four directions an arrow head can point.
enum Dir {
  up(-1, 0),
  down(1, 0),
  left(0, -1),
  right(0, 1);

  const Dir(this.dRow, this.dCol);

  final int dRow;
  final int dCol;

  Dir get opposite => switch (this) {
        Dir.up => Dir.down,
        Dir.down => Dir.up,
        Dir.left => Dir.right,
        Dir.right => Dir.left,
      };

  /// Direction that leads from [from] to the orthogonally adjacent [to].
  static Dir between(Cell from, Cell to) {
    final dr = to.row - from.row;
    final dc = to.col - from.col;
    for (final d in Dir.values) {
      if (d.dRow == dr && d.dCol == dc) return d;
    }
    throw ArgumentError('$from and $to are not orthogonally adjacent');
  }
}

/// A cell on the board, addressed by row and column.
class Cell {
  const Cell(this.row, this.col);

  final int row;
  final int col;

  Cell step(Dir d, [int n = 1]) => Cell(row + d.dRow * n, col + d.dCol * n);

  bool isAdjacentTo(Cell other) =>
      (row - other.row).abs() + (col - other.col).abs() == 1;

  List<int> toJson() => [row, col];

  factory Cell.fromJson(List<dynamic> json) =>
      Cell(json[0] as int, json[1] as int);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

/// An arrow on the board.
///
/// [cells] runs from the tail to the head. Consecutive cells are orthogonally
/// adjacent, so the body can bend any number of times. The head always points
/// along the last segment, i.e. [direction] is the direction from the
/// second-to-last cell to the last one. When tapped, the arrow slithers
/// forward along its own body and then straight out in [direction].
class ArrowPath {
  ArrowPath({required this.id, required List<Cell> cells})
      : cells = List.unmodifiable(cells) {
    if (cells.length < 2) {
      throw ArgumentError('An arrow needs at least two cells');
    }
    for (var i = 1; i < cells.length; i++) {
      if (!cells[i - 1].isAdjacentTo(cells[i])) {
        throw ArgumentError('Arrow $id has a gap between cell ${i - 1} and $i');
      }
    }
  }

  final int id;
  final List<Cell> cells;

  Cell get head => cells.last;
  Cell get tail => cells.first;
  int get length => cells.length;
  Dir get direction => Dir.between(cells[cells.length - 2], cells.last);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cells': [for (final c in cells) c.toJson()],
      };

  factory ArrowPath.fromJson(Map<String, dynamic> json) => ArrowPath(
        id: json['id'] as int,
        cells: [
          for (final c in json['cells'] as List<dynamic>)
            Cell.fromJson(c as List<dynamic>),
        ],
      );

  @override
  String toString() => 'Arrow#$id${cells.join('-')}';
}
