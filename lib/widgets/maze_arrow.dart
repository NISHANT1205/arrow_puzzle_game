// lib/widgets/maze_arrow.dart
//
// Rendering layer for the "maze-pipe" arrow style.
//
// This file is pure geometry + painting: it knows nothing about levels, moves,
// collision or input. It exposes one reusable component, [MazeArrow], which
// takes an orthogonal polyline, a colour state and a cell size, and draws it
// with a chunky flat body and a solid triangular head.
//
// Every dimension is derived from the cell size (see [MazeArrowMetrics]), so
// the same code scales across screen densities and grid sizes.

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Flat palette shared by the board, the HUD and the app icon.
class ArrowPalette {
  const ArrowPalette._();

  /// Idle / blocked arrows.
  static const Color navy = Color(0xFF0F1B4C);

  /// Selected arrow, valid move, solved path.
  static const Color blue = Color(0xFF2E90FF);

  /// Hairline used around the white board surface.
  static const Color border = Color(0xFFE6E8EE);
}

/// The visual state an arrow can be drawn in.
enum ArrowVisualState {
  /// Idle or blocked.
  idle,

  /// Selected, valid move, or part of a solved path.
  active;

  Color get color =>
      this == ArrowVisualState.active ? ArrowPalette.blue : ArrowPalette.navy;
}

/// All maze-arrow proportions, expressed as ratios so nothing is hardcoded to
/// a pixel size.
///
/// Reference spec (base canvas 512, stroke 22):
///   head base width = 2.2 x stroke, head length = 1.9 x stroke,
///   tip corner radius = 2 units = 0.09 x stroke.
class MazeArrowMetrics {
  const MazeArrowMetrics._();

  /// Stroke width as a fraction of the cell size. Deliberately chunky.
  static const double strokeRatio = 0.14;

  /// Head base width, in stroke widths.
  static const double headBaseRatio = 2.2;

  /// Head length, in stroke widths.
  static const double headLengthRatio = 1.9;

  /// Tip corner radius, in stroke widths (barely rounded).
  static const double tipRadiusRatio = 0.09;

  /// Length of a single-cell arrow, as a fraction of the cell size.
  static const double arrowLengthRatio = 0.80;

  /// Corner radius of the cell highlight, as a fraction of the cell size.
  static const double highlightRadiusRatio = 0.22;

  /// Press / hover feedback.
  static const double pressScale = 1.04;
  static const Duration pressDuration = Duration(milliseconds: 120);

  /// Navy -> blue transition.
  static const Duration colorDuration = Duration(milliseconds: 250);

  /// Body translating along its axis, head leading.
  static const Duration moveDuration = Duration(milliseconds: 180);
}

/// Draws an orthogonal polyline with a chunky flat body and a solid triangular
/// head on the final segment.
///
/// [points] are in *cell units*: `Offset(1, 0)` is one cell to the right of
/// `Offset(0, 0)`. They are multiplied by [cellSize] at paint time, so the same
/// polyline works for a single tile and for a path that spans the whole board.
class MazeArrowPainter extends CustomPainter {
  const MazeArrowPainter({
    required this.points,
    required this.color,
    required this.cellSize,
    this.strokeRatio = MazeArrowMetrics.strokeRatio,
    this.showHead = true,
  });

  /// Orthogonal polyline in cell units. The head sits on the last segment.
  final List<Offset> points;

  /// Body and head fill colour.
  final Color color;

  /// Pixels per cell unit.
  final double cellSize;

  /// Stroke width as a fraction of [cellSize].
  final double strokeRatio;

  /// Whether the final segment ends in an arrow head.
  final bool showHead;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || cellSize <= 0) return;

    final stroke = cellSize * strokeRatio;
    final headLength = stroke * MazeArrowMetrics.headLengthRatio;
    final headHalfBase = stroke * MazeArrowMetrics.headBaseRatio / 2;

    final pixels = [
      for (final point in points) point * cellSize,
    ];

    final tip = pixels.last;
    final previous = pixels[pixels.length - 2];
    final delta = tip - previous;
    final length = delta.distance;
    if (length == 0) return;
    final axis = delta / length;

    // The body stops exactly where the head starts, so the two never overlap
    // into a bulge. If the last segment is shorter than the head, the head
    // simply absorbs it.
    final bodyEnd = showHead
        ? (length <= headLength ? previous : tip - axis * headLength)
        : tip;

    final body = Path()..moveTo(pixels.first.dx, pixels.first.dy);
    for (var i = 1; i < pixels.length - 1; i++) {
      body.lineTo(pixels[i].dx, pixels[i].dy);
    }
    body.lineTo(bodyEnd.dx, bodyEnd.dy);

    canvas.drawPath(
      body,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    if (showHead) {
      canvas.drawPath(
        _headPath(
          tip: tip,
          base: bodyEnd,
          axis: axis,
          halfBase: headHalfBase,
          tipRadius: stroke * MazeArrowMetrics.tipRadiusRatio,
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  /// Solid triangle: sharp base corners, a barely rounded tip.
  Path _headPath({
    required Offset tip,
    required Offset base,
    required Offset axis,
    required double halfBase,
    required double tipRadius,
  }) {
    final perpendicular = Offset(-axis.dy, axis.dx);
    final left = base + perpendicular * halfBase;
    final right = base - perpendicular * halfBase;

    // Walk back from the tip along both edges by a hair, then round the corner
    // between the two points.
    final trim = tipRadius * 2;
    final towardsLeft = (left - tip) / (left - tip).distance;
    final towardsRight = (right - tip) / (right - tip).distance;
    final tipLeft = tip + towardsLeft * trim;
    final tipRight = tip + towardsRight * trim;

    return Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tipLeft.dx, tipLeft.dy)
      ..quadraticBezierTo(tip.dx, tip.dy, tipRight.dx, tipRight.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant MazeArrowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.strokeRatio != strokeRatio ||
      oldDelegate.showHead != showHead ||
      !listEquals(oldDelegate.points, points);
}

/// The one reusable maze-arrow component.
///
/// Give it a polyline (cell units), a colour state and a cell size; it renders
/// the chunky body plus the solid head. Used for single-cell arrows and for
/// multi-cell paths alike.
class MazeArrow extends StatelessWidget {
  const MazeArrow({
    super.key,
    required this.points,
    required this.cellSize,
    this.state = ArrowVisualState.idle,
    this.color,
    this.strokeRatio = MazeArrowMetrics.strokeRatio,
    this.showHead = true,
    this.animateColor = true,
  });

  /// Builds the polyline for a single arrow sitting in the middle of one cell,
  /// pointing along [direction] (which may be diagonal).
  factory MazeArrow.single({
    Key? key,
    required Offset direction,
    required double cellSize,
    ArrowVisualState state = ArrowVisualState.idle,
    Color? color,
    double strokeRatio = MazeArrowMetrics.strokeRatio,
    double lengthRatio = MazeArrowMetrics.arrowLengthRatio,
    bool animateColor = true,
    int variant = 0,
  }) {
    final length = direction.distance;
    final axis = length == 0 ? const Offset(0, -1) : direction / length;
    final points = _singleCellTail(axis, variant);
    return MazeArrow(
      key: key,
      points: points,
      cellSize: cellSize,
      state: state,
      color: color,
      strokeRatio: strokeRatio,
      animateColor: animateColor,
    );
  }

  /// A long, orthogonal tail followed by a solid-headed final segment.
  /// Cardinal arrows use a deliberate L bend, matching the reference maze
  /// artwork instead of looking like isolated arrow icons.
  static List<Offset> _singleCellTail(Offset axis, int variant) {
    const near = .03;
    const far = .97;
    const centre = .50;
    const tailLaneA = .12;
    const tailLaneB = .88;

    final normalizedVariant = variant.abs() % 6;
    if (axis.dx.abs() < .01 || axis.dy.abs() < .01) {
      final upPath = switch (normalizedVariant) {
        1 => const [
            Offset(tailLaneA, far),
            Offset(tailLaneA, .50),
            Offset(centre, .50),
            Offset(centre, near),
          ],
        2 => const [
            Offset(tailLaneB, far),
            Offset(tailLaneB, .70),
            Offset(.28, .70),
            Offset(.28, .45),
            Offset(centre, .45),
            Offset(centre, near),
          ],
        3 => const [
            Offset(tailLaneA, far),
            Offset(tailLaneA, .80),
            Offset(.70, .80),
            Offset(.70, .61),
            Offset(.30, .61),
            Offset(.30, .43),
            Offset(centre, .43),
            Offset(centre, near),
          ],
        4 => const [
            Offset(tailLaneB, far),
            Offset(tailLaneB, .74),
            Offset(.28, .74),
            Offset(.28, .55),
            Offset(.68, .55),
            Offset(.68, .36),
            Offset(centre, .36),
            Offset(centre, near),
          ],
        5 => const [
            Offset(tailLaneB, far),
            Offset(tailLaneB, .85),
            Offset(tailLaneA, .85),
            Offset(tailLaneA, .67),
            Offset(tailLaneB, .67),
            Offset(tailLaneB, .49),
            Offset(centre, .49),
            Offset(centre, near),
          ],
        _ => const [
            Offset(centre, far),
            Offset(centre, near),
          ],
      };
      return _rotateUpPath(upPath, axis);
    }

    // Diagonal gameplay directions stay visually orthogonal: their overall
    // tail-to-tip vector communicates the diagonal while the final head points
    // along the dominant vertical leg.
    final goesRight = axis.dx >= 0;
    final goesDown = axis.dy >= 0;
    final start = Offset(goesRight ? near : far, goesDown ? near : far);
    final tip = Offset(goesRight ? far : near, goesDown ? far : near);
    final laneX = goesRight ? .36 : .64;
    final laneY = goesDown ? .55 : .45;
    return switch (normalizedVariant) {
      0 => [start, Offset(tip.dx, start.dy), tip],
      1 => [
          start,
          Offset(laneX, start.dy),
          Offset(laneX, laneY),
          Offset(tip.dx, laneY),
          tip,
        ],
      2 => [
          start,
          Offset(goesRight ? .22 : .78, start.dy),
          Offset(goesRight ? .22 : .78, goesDown ? .72 : .28),
          Offset(goesRight ? .68 : .32, goesDown ? .72 : .28),
          Offset(goesRight ? .68 : .32, laneY),
          Offset(tip.dx, laneY),
          tip,
        ],
      _ => [
          start,
          Offset(goesRight ? .48 : .52, start.dy),
          Offset(goesRight ? .48 : .52, laneY),
          Offset(tip.dx, laneY),
          tip,
        ],
    };
  }

  static List<Offset> _rotateUpPath(List<Offset> points, Offset axis) {
    if (axis.dy < -.9) return points;
    if (axis.dx > .9) {
      return [for (final p in points) Offset(1 - p.dy, p.dx)];
    }
    if (axis.dy > .9) {
      return [for (final p in points) Offset(1 - p.dx, 1 - p.dy)];
    }
    return [for (final p in points) Offset(p.dy, 1 - p.dx)];
  }

  /// Orthogonal polyline in cell units; the head sits on the last segment.
  final List<Offset> points;

  /// Pixels per cell unit.
  final double cellSize;

  /// Idle (navy) or active (blue).
  final ArrowVisualState state;

  /// Overrides [state]'s colour when set.
  final Color? color;

  final double strokeRatio;
  final bool showHead;

  /// Animate navy <-> blue over [MazeArrowMetrics.colorDuration].
  final bool animateColor;

  @override
  Widget build(BuildContext context) {
    final target = color ?? state.color;

    Widget paint(Color value) => CustomPaint(
          painter: MazeArrowPainter(
            points: points,
            color: value,
            cellSize: cellSize,
            strokeRatio: strokeRatio,
            showHead: showHead,
          ),
          isComplex: false,
        );

    if (!animateColor) return paint(target);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: MazeArrowMetrics.colorDuration,
      curve: Curves.easeOut,
      builder: (_, value, __) => paint(value ?? target),
    );
  }
}
