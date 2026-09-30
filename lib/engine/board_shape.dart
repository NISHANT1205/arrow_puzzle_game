// lib/engine/board_shape.dart
//
// The surface arrows live on. A shape answers two questions for the rules:
// which cell is straight ahead (lanes may turn a corner onto another face),
// and which cell is next to another for an arrow's body. It also gives every
// cell a 3D position, which the board view projects onto the screen.
//
//  * RectShape - the flat rectangular board (z = 0).
//  * CubeShape - arrows on the faces of a cube: the three faces seen from the
//    front corner, or all six sides. Bodies stay on one face. An escape lane
//    runs over one cube edge onto the next face and leaves the cube at the
//    edge after that (or at the outline, for the three-face cube).

import 'dart:math' as math;

import '../models/arrow_path.dart';

/// A point or direction in 3D, in cell units.
class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  double get length => math.sqrt(dot(this));

  bool same(V3 o) => (this - o).length < 1e-9;

  @override
  String toString() => '($x, $y, $z)';
}

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

/// Where the camera looks at a cube from: [yaw] around the vertical axis and
/// [pitch] above the horizon, in radians.
class CubeView {
  const CubeView(this.yaw, this.pitch);

  final double yaw;
  final double pitch;

  /// The classic isometric view from the front corner, showing the top,
  /// left and right faces.
  static const iso = CubeView(math.pi / 4, 0.6154797086703874);

  /// Unit vector from the cube towards the viewer.
  V3 get toViewer => V3(
        math.cos(pitch) * math.cos(yaw),
        math.cos(pitch) * math.sin(yaw),
        math.sin(pitch),
      );

  /// Screen right and screen up, as 3D directions.
  V3 get right => V3(math.sin(yaw), -math.cos(yaw), 0);
  V3 get up => V3(
        -math.sin(pitch) * math.cos(yaw),
        -math.sin(pitch) * math.sin(yaw),
        math.cos(pitch),
      );

  CubeView copyWith({double? yaw, double? pitch}) =>
      CubeView(yaw ?? this.yaw, pitch ?? this.pitch);

  @override
  String toString() => 'CubeView(yaw: $yaw, pitch: $pitch)';
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

  /// Each cell (and direction of travel) straight ahead of [from] along [d],
  /// up to where the lane leaves the board.
  Iterable<(Cell, Dir)> laneSteps(Cell from, Dir d) sync* {
    var next = ahead(from, d);
    while (next != null) {
      yield next;
      next = ahead(next.$1, next.$2);
    }
  }

  /// Cells straight ahead of [from] along [d] up to where the board ends.
  Iterable<Cell> lane(Cell from, Dir d) => laneSteps(from, d).map((s) => s.$1);

  /// The neighbour of [c] along [d] that an arrow body may continue into, or
  /// null. Bodies never cross from one face to another.
  Cell? bodyStep(Cell c, Dir d);

  /// Distance of [c] from the edge of its face, in cells.
  int depth(Cell c);

  /// Face that [c] is on (always 0 on a flat board).
  int faceOf(Cell c) => 0;

  /// Number of faces.
  int get faceCount => 1;

  /// Outward normal of [face].
  V3 normalOf(int face) => const V3(0, 0, 1);

  /// 3D centre of [c].
  V3 center3(Cell c);

  /// 3D point half a cell from [c]'s centre along [d]: the edge crossed when
  /// leaving [c] that way.
  V3 edge3(Cell c, Dir d);

  /// Screen position (cell units) of the 3D point [p] seen from [view].
  Pt project(V3 p, [CubeView view = CubeView.iso]);

  /// Screen position of the centre of [c], in the default view.
  Pt center(Cell c) => project(center3(c));

  /// Screen position of [edge3], in the default view.
  Pt edgePoint(Cell c, Dir d) => project(edge3(c, d));

  /// Width and height of the drawn board, in cell units.
  (double, double) get extent;

  /// Corners of each face, in 3D (empty for flat boards).
  List<List<V3>> get faceCorners => const [];

  /// Whether [face] faces the camera in [view].
  bool faceVisible(int face, CubeView view) => true;

  Map<String, dynamic> toJson();

  static BoardShape fromJson(Map<String, dynamic>? json, int rows, int cols) {
    if (json == null || json['t'] == 'rect') return RectShape(rows, cols);
    if (json['t'] == 'cube') {
      return CubeShape(json['n'] as int, allSides: json['all'] == true);
    }
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
  V3 center3(Cell c) => V3(c.col + .5, c.row + .5, 0);

  @override
  V3 edge3(Cell c, Dir d) => center3(c) + V3(d.dCol * .5, d.dRow * .5, 0);

  @override
  Pt project(V3 p, [CubeView view = CubeView.iso]) => Pt(p.x, p.y);

  @override
  (double, double) get extent => (cols.toDouble(), rows.toDouble());

  @override
  Map<String, dynamic> toJson() => {'t': 'rect'};
}

/// One face of the cube: where its local cell (0, 0) corner is, and the 3D
/// directions of its local "right" (columns) and "down" (rows).
class _Face {
  const _Face(this.normal, this.corner, this.right, this.down);
  final V3 normal;
  final V3 corner; // in multiples of n
  final V3 right;
  final V3 down;
}

/// Arrows on the faces of an n x n x n cube filling [0, n]^3.
///
/// Faces are stored one after another, n rows each: 0 top (+z), 1 left (+y),
/// 2 right (+x) - the three seen from the front corner - then, when
/// [allSides] is set, 3 bottom (-z), 4 back-left (-y) and 5 back-right (-x).
///
/// A lane that runs off a face continues over the edge onto the neighbouring
/// face, heading straight away from the face it came from. At the next edge
/// it flies off the cube. Without [allSides], the three hidden faces are
/// missing, so a lane heading onto one of them leaves the cube there.
class CubeShape extends BoardShape {
  const CubeShape(this.n, {this.allSides = false});

  /// Cells along each edge of the cube.
  final int n;

  /// Arrows on all six sides (the player turns the cube to see them all).
  final bool allSides;

  static const int top = 0, left = 1, right = 2;
  static const int bottom = 3, backLeft = 4, backRight = 5;

  static const _faces = [
    _Face(V3(0, 0, 1), V3(0, 0, 1), V3(1, 0, 0), V3(0, 1, 0)),
    _Face(V3(0, 1, 0), V3(0, 1, 1), V3(1, 0, 0), V3(0, 0, -1)),
    _Face(V3(1, 0, 0), V3(1, 1, 1), V3(0, -1, 0), V3(0, 0, -1)),
    _Face(V3(0, 0, -1), V3(0, 1, 0), V3(1, 0, 0), V3(0, -1, 0)),
    _Face(V3(0, -1, 0), V3(1, 0, 1), V3(-1, 0, 0), V3(0, 0, -1)),
    _Face(V3(-1, 0, 0), V3(0, 0, 1), V3(0, 1, 0), V3(0, 0, -1)),
  ];

  @override
  int get faceCount => allSides ? 6 : 3;

  @override
  int get rows => faceCount * n;
  @override
  int get cols => n;

  @override
  int faceOf(Cell c) => c.row ~/ n;

  @override
  V3 normalOf(int face) => _faces[face].normal;

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
  V3 _vec(int face, Dir d) {
    final f = _faces[face];
    return switch (d) {
      Dir.right => f.right,
      Dir.left => f.right * -1,
      Dir.down => f.down,
      Dir.up => f.down * -1,
    };
  }

  @override
  V3 center3(Cell c) {
    final f = _faces[faceOf(c)];
    return f.corner * n.toDouble() +
        f.right * (c.col + .5) +
        f.down * (c.row % n + .5);
  }

  @override
  V3 edge3(Cell c, Dir d) => center3(c) + _vec(faceOf(c), d) * .5;

  /// Cell on [face] whose centre is the 3D point [p].
  Cell _cellAt(int face, V3 p) {
    final f = _faces[face];
    final rel = p - f.corner * n.toDouble();
    return Cell(
      face * n + (rel.dot(f.down) - .5).round(),
      (rel.dot(f.right) - .5).round(),
    );
  }

  @override
  (Cell, Dir)? ahead(Cell c, Dir d) {
    final same = bodyStep(c, d);
    if (same != null) return (same, d);

    // Over the edge: continue on the face whose normal is the direction of
    // travel, heading away from the face we left.
    final face = faceOf(c);
    final travel = _vec(face, d);
    final next = _faces.indexWhere((f) => f.normal.same(travel));
    if (next >= faceCount) return null; // A missing face: off the cube.

    final normal = _faces[face].normal;
    final p = center3(c) + travel * .5 - normal * .5;
    final newTravel = normal * -1;
    final newDir = Dir.values.firstWhere((x) => _vec(next, x).same(newTravel));
    return (_cellAt(next, p), newDir);
  }

  @override
  Iterable<(Cell, Dir)> laneSteps(Cell from, Dir d) sync* {
    var face = faceOf(from);
    var crossed = false;
    var next = ahead(from, d);
    while (next != null) {
      final nextFace = faceOf(next.$1);
      if (nextFace != face) {
        // One edge is taken; at the second the arrow flies off the cube.
        if (crossed) return;
        crossed = true;
        face = nextFace;
      }
      yield next;
      next = ahead(next.$1, next.$2);
    }
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

  /// Screen units per cube unit. Chosen so every cube axis is one cell long
  /// in the isometric view.
  static const _scale = 1.2247448713915890;

  @override
  Pt project(V3 p, [CubeView view = CubeView.iso]) {
    final half = n / 2;
    final rel = p - V3(half, half, half);
    final (w, h) = extent;
    return Pt(
      rel.dot(view.right) * _scale + w / 2,
      -rel.dot(view.up) * _scale + h / 2,
    );
  }

  @override
  (double, double) get extent =>
      allSides ? (2.2 * n, 2.2 * n) : (math.sqrt(3) * n, 2.0 * n);

  @override
  List<List<V3>> get faceCorners {
    final m = n.toDouble();
    return [
      for (var i = 0; i < faceCount; i++)
        () {
          final f = _faces[i];
          final o = f.corner * m;
          return [
            o,
            o + f.right * m,
            o + f.right * m + f.down * m,
            o + f.down * m,
          ];
        }(),
    ];
  }

  @override
  bool faceVisible(int face, CubeView view) =>
      _faces[face].normal.dot(view.toViewer) > 1e-6;

  @override
  Map<String, dynamic> toJson() =>
      {'t': 'cube', 'n': n, if (allSides) 'all': true};
}
