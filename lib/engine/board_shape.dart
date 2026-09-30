// lib/engine/board_shape.dart
//
// The surface arrows live on. A shape answers two questions for the rules:
// which cell is straight ahead (lanes may turn a corner onto another face),
// and which cell is next to another for an arrow's body. It also places
// cells on screen.
//
//  * RectShape - the flat rectangular board.
//  * CubeShape - the three visible faces of an isometric cube. Bodies stay
//    on one face, but escape lanes run over the cube's edges onto the next
//    face and only leave at the cube's outline.

import 'dart:math' as math;

import '../models/arrow_path.dart';

/// A screen point in cell units. (The engine stays free of Flutter so the
/// level tools run in plain Dart.)
class Pt {
  const Pt(this.x, this.y);
  final double x, y;

  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator *(double k) => Pt(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);

  @override
  bool operator ==(Object other) => other is Pt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

abstract class BoardShape {
  const BoardShape();

  /// Size of the underlying cell grid (cells are addressed as row, col).
  int get rows;
  int get cols;

  /// Every playable cell.
  Iterable<Cell> get cells;

  bool contains(Cell c);

  /// The cell straight ahead of [c] when moving along [d], and the direction
  /// of travel there (it changes when a lane turns onto another face), or
  /// null when the move leaves the board.
  (Cell, Dir)? ahead(Cell c, Dir d);

  /// Cells straight ahead of [from] along [d] up to where the board ends,
  /// following the lane around corners.
  Iterable<Cell> lane(Cell from, Dir d) sync* {
    var next = ahead(from, d);
    while (next != null) {
      yield next.$1;
      next = ahead(next.$1, next.$2);
    }
  }

  /// The neighbour of [c] along [d] that an arrow body may continue into, or
  /// null. Bodies never cross from one face to another.
  Cell? bodyStep(Cell c, Dir d);

  /// Distance of [c] from the edge of its face, in cells.
  int depth(Cell c);

  /// Screen position of the centre of [c], in cell units.
  Pt center(Cell c);

  /// Screen position of the point half a cell from [c]'s centre along [d]:
  /// the edge crossed when leaving [c] that way.
  Pt edgePoint(Cell c, Dir d);

  /// Width and height of the drawn board, in cell units.
  (double, double) get extent;

  /// Faces to shade, as screen polygons in cell units (empty for flat
  /// boards). Listed top, left, right.
  List<List<Pt>> get faces => const [];

  Map<String, dynamic> toJson();

  static BoardShape fromJson(Map<String, dynamic>? json, int rows, int cols) {
    if (json == null || json['t'] == 'rect') return RectShape(rows, cols);
    if (json['t'] == 'cube') return CubeShape(json['n'] as int);
    throw FormatException('Unknown board shape ${json['t']}');
  }
}

class RectShape extends BoardShape {
  const RectShape(this.rows, this.cols);

  @override
  final int rows;
  @override
  final int cols;

  @override
  Iterable<Cell> get cells sync* {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        yield Cell(r, c);
      }
    }
  }

  @override
  bool contains(Cell c) =>
      c.row >= 0 && c.row < rows && c.col >= 0 && c.col < cols;

  @override
  (Cell, Dir)? ahead(Cell c, Dir d) {
    final next = c.step(d);
    return contains(next) ? (next, d) : null;
  }

  @override
  Cell? bodyStep(Cell c, Dir d) {
    final next = c.step(d);
    return contains(next) ? next : null;
  }

  @override
  int depth(Cell c) => math.min(
        math.min(c.row, rows - 1 - c.row),
        math.min(c.col, cols - 1 - c.col),
      );

  @override
  Pt center(Cell c) => Pt(c.col + .5, c.row + .5);

  @override
  Pt edgePoint(Cell c, Dir d) => center(c) + Pt(d.dCol * .5, d.dRow * .5);

  @override
  (double, double) get extent => (cols.toDouble(), rows.toDouble());

  @override
  Map<String, dynamic> toJson() => {'t': 'rect'};
}

/// A point or direction in the cube's 3D space.
class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x, y, z;

  _V3 operator +(_V3 o) => _V3(x + o.x, y + o.y, z + o.z);
  _V3 operator -(_V3 o) => _V3(x - o.x, y - o.y, z - o.z);
  _V3 operator *(double k) => _V3(x * k, y * k, z * k);

  bool same(_V3 o) =>
      (x - o.x).abs() < 1e-9 &&
      (y - o.y).abs() < 1e-9 &&
      (z - o.z).abs() < 1e-9;
}

/// The three visible faces of an n x n x n cube, seen from the corner.
///
/// The cube fills [0, n]^3. The visible faces are top (z = n), left (y = n)
/// and right (x = n); they meet at the front corner, drawn in the middle of
/// the hexagon outline. Cells are stored face after face: rows 0..n-1 are
/// the top face, n..2n-1 the left face, 2n..3n-1 the right face.
///
/// On each face "up" on screen is up the face: on the side faces local rows
/// run down the face, on the top face they run from the back corner towards
/// the left side.
class CubeShape extends BoardShape {
  const CubeShape(this.n);

  /// Cells along each edge of the cube.
  final int n;

  static const int top = 0, left = 1, right = 2;

  static const _normals = [_V3(0, 0, 1), _V3(0, 1, 0), _V3(1, 0, 0)];

  @override
  int get rows => 3 * n;
  @override
  int get cols => n;

  int faceOf(Cell c) => c.row ~/ n;

  @override
  Iterable<Cell> get cells sync* {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        yield Cell(r, c);
      }
    }
  }

  @override
  bool contains(Cell c) =>
      c.row >= 0 && c.row < rows && c.col >= 0 && c.col < cols;

  /// 3D direction of local [d] on [face].
  _V3 _vec(int face, Dir d) => switch ((face, d)) {
        (top, Dir.right) => const _V3(1, 0, 0),
        (top, Dir.left) => const _V3(-1, 0, 0),
        (top, Dir.down) => const _V3(0, 1, 0),
        (top, Dir.up) => const _V3(0, -1, 0),
        (left, Dir.right) => const _V3(1, 0, 0),
        (left, Dir.left) => const _V3(-1, 0, 0),
        (left, Dir.down) => const _V3(0, 0, -1),
        (left, Dir.up) => const _V3(0, 0, 1),
        (right, Dir.right) => const _V3(0, -1, 0),
        (right, Dir.left) => const _V3(0, 1, 0),
        (right, Dir.down) => const _V3(0, 0, -1),
        _ => const _V3(0, 0, 1), // (right, up)
      };

  /// 3D centre of a cell on the cube's surface.
  _V3 _point(Cell c) {
    final face = faceOf(c);
    final r = c.row % n + .5;
    final col = c.col + .5;
    return switch (face) {
      top => _V3(col, r, n.toDouble()),
      left => _V3(col, n.toDouble(), n - r),
      _ => _V3(n.toDouble(), n - col, n - r),
    };
  }

  /// Cell on [face] whose centre is the 3D point [p].
  Cell _cellAt(int face, _V3 p) {
    final (r, c) = switch (face) {
      top => (p.y - .5, p.x - .5),
      left => (n - p.z - .5, p.x - .5),
      _ => (n - p.z - .5, n - p.y - .5),
    };
    return Cell(face * n + r.round(), c.round());
  }

  @override
  (Cell, Dir)? ahead(Cell c, Dir d) {
    final same = bodyStep(c, d);
    if (same != null) return (same, d);

    // Over the edge: continue on the face whose normal is the direction of
    // travel, if that face is one of the visible three.
    final face = faceOf(c);
    final travel = _vec(face, d);
    final next = _normals.indexWhere((nrm) => nrm.same(travel));
    if (next < 0) return null; // Over the outline, off the cube.

    final normal = _normals[face];
    final p = _point(c) + travel * .5 - normal * .5;
    final newTravel = normal * -1;
    final newDir = Dir.values.firstWhere((x) => _vec(next, x).same(newTravel));
    return (_cellAt(next, p), newDir);
  }

  @override
  Cell? bodyStep(Cell c, Dir d) {
    final r = c.row % n + d.dRow;
    final col = c.col + d.dCol;
    if (r < 0 || r >= n || col < 0 || col >= n) return null;
    return Cell(faceOf(c) * n + r, col);
  }

  @override
  int depth(Cell c) {
    final r = c.row % n;
    return math.min(math.min(r, n - 1 - r), math.min(c.col, n - 1 - c.col));
  }

  static const _cos30 = 0.8660254037844386;

  /// Isometric projection, shifted so the hexagon starts at (0, 0). Every
  /// cube axis projects to unit length, so one cell stays one cell long.
  Pt _project(_V3 p) =>
      Pt((p.x - p.y) * _cos30 + n * _cos30, (p.x + p.y) * .5 - p.z + n);

  @override
  Pt center(Cell c) => _project(_point(c));

  @override
  Pt edgePoint(Cell c, Dir d) => _project(_point(c) + _vec(faceOf(c), d) * .5);

  @override
  (double, double) get extent => (2 * n * _cos30, 2.0 * n);

  @override
  List<List<Pt>> get faces {
    final m = n.toDouble();
    List<Pt> quad(List<_V3> corners) => [for (final p in corners) _project(p)];
    return [
      quad([_V3(0, 0, m), _V3(m, 0, m), _V3(m, m, m), _V3(0, m, m)]),
      quad([_V3(0, m, m), _V3(m, m, m), _V3(m, m, 0), _V3(0, m, 0)]),
      quad([_V3(m, m, m), _V3(m, 0, m), _V3(m, 0, 0), _V3(m, m, 0)]),
    ];
  }

  @override
  Map<String, dynamic> toJson() => {'t': 'cube', 'n': n};
}
