// lib/widgets/arrow_board_view.dart
//
// Draws the board and every arrow, turns taps into moves and animates
// them:
//  * escape  – the arrow slithers along its own body and out of the board;
//  * blocked – the arrow creeps forward until its head bumps the arrow in the
//              way, flashes red and snaps back.
//
// Positions come from the level's BoardShape in 3D, so the same code draws
// flat boards and cubes. A cube can be turned with one finger and zoomed
// with two; faces turned away from the camera, and arrows on them, are not
// drawn and can't be tapped. Lanes bend over the cube's edges.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/board_shape.dart';
import '../engine/puzzle_board.dart';
import '../models/arrow_path.dart';
import '../state/game_controller.dart';

/// Colours used on the board.
class BoardPalette {
  const BoardPalette({
    required this.arrow,
    required this.dot,
    required this.hint,
    required this.error,
    required this.faceLight,
    required this.faceDark,
    required this.faceEdge,
  });

  final Color arrow;
  final Color dot;
  final Color hint;
  final Color error;

  /// Cube faces are shaded between these by how much they face the light.
  final Color faceLight;
  final Color faceDark;
  final Color faceEdge;

  static const light = BoardPalette(
    arrow: Color(0xFF1C1F33),
    dot: Color(0xFFB9BECE),
    hint: Color(0xFF2E90FF),
    error: Color(0xFFF03E5A),
    faceLight: Color(0xFFF5F7FC),
    faceDark: Color(0xFFCBD2E3),
    faceEdge: Color(0xFFB3BACD),
  );

  static const dark = BoardPalette(
    arrow: Color(0xFFEDEFF7),
    dot: Color(0xFF4A5068),
    hint: Color(0xFF4DA3FF),
    error: Color(0xFFFF5470),
    faceLight: Color(0xFF2A2F48),
    faceDark: Color(0xFF14172A),
    faceEdge: Color(0xFF3A4060),
  );
}

class ArrowBoardView extends StatefulWidget {
  const ArrowBoardView({
    super.key,
    required this.controller,
    required this.cellSize,
    required this.palette,
    this.onMove,
    this.onSettled,
  });

  final GameController controller;
  final double cellSize;
  final BoardPalette palette;

  /// Called right after every accepted tap.
  final ValueChanged<MoveResult>? onMove;

  /// Called when the last running animation has finished.
  final VoidCallback? onSettled;

  @override
  State<ArrowBoardView> createState() => ArrowBoardViewState();
}

/// A point on an arrow's route: where it is in 3D, and the face that the
/// stretch of route leading to it lies on (-1 once off the board).
class TrackPoint {
  const TrackPoint(this.p, this.face);
  final V3 p;
  final int face;
}

class _Motion {
  _Motion({
    required this.arrow,
    required this.escape,
    required this.distance,
    required this.duration,
    required this.startedAt,
    required BoardShape shape,
  }) : track = buildTrack(shape, arrow, distance.ceil() + 1);

  final ArrowPath arrow;
  final bool escape;

  /// How far (in cells) the head travels: out of the board for an escape,
  /// up to the blocker for a bump.
  final double distance;
  final Duration duration;
  final Duration startedAt;
  final List<TrackPoint> track;

  double t(Duration now) {
    final elapsed = (now - startedAt).inMicroseconds / duration.inMicroseconds;
    return elapsed.clamp(0.0, 1.0);
  }

  bool isDone(Duration now) => t(now) >= 1;
}

class ArrowBoardViewState extends State<ArrowBoardView>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _pulse;
  late final AnimationController _turn;
  Duration _now = Duration.zero;
  final Map<int, _Motion> _motions = {};

  /// Arrows that recently bumped, mapped to when the red flash ends.
  final Map<int, Duration> _flashUntil = {};
  static const _flash = Duration(milliseconds: 650);

  // Cube camera.
  CubeView _view = CubeView.iso;
  CubeView _turnFrom = CubeView.iso;
  CubeView _turnTo = CubeView.iso;
  double _zoom = 1;
  double _zoomAtStart = 1;
  Size _box = Size.zero;
  int? _lastHint;

  BoardShape get _shape => widget.controller.level.shape;
  bool get _isCube => _shape is CubeShape;
  bool get _allSides {
    final shape = _shape;
    return shape is CubeShape && shape.allSides;
  }

  /// The current camera.
  @visibleForTesting
  CubeView get view => _view;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _turn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(_onTurn);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ArrowBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _motions.clear();
      _flashUntil.clear();
      _view = CubeView.iso;
      _zoom = 1;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _pulse.dispose();
    _turn.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final controller = widget.controller;
    // A restart puts every arrow back; drop animations of the old run.
    if (controller.moves == 0 && _motions.isNotEmpty) {
      _motions.clear();
      _flashUntil.clear();
    }
    // Turn the cube so a new hint is in sight.
    final hint = controller.hintArrowId;
    if (hint != null && hint != _lastHint) {
      final arrow = controller.board.arrowById(hint);
      if (arrow != null) lookAt(arrow.head);
    }
    _lastHint = hint;
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    final hadMotion = _motions.isNotEmpty || _flashUntil.isNotEmpty;
    _motions.removeWhere((_, m) => m.isDone(elapsed));
    _flashUntil.removeWhere((_, until) => elapsed >= until);
    if (_motions.isEmpty && _flashUntil.isEmpty) {
      _ticker.stop();
      _now = Duration.zero;
      if (hadMotion) widget.onSettled?.call();
    }
    setState(() {});
  }

  void _startTicker() {
    if (!_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
  }

  // ------------------------------------------------------------- camera

  /// How far the camera may turn. The three-face cube only turns within the
  /// corner it is seen from, so its missing faces never show.
  CubeView _clamp(CubeView v) {
    if (_allSides) return v.copyWith(pitch: v.pitch.clamp(-1.35, 1.35));
    return CubeView(v.yaw.clamp(.3, 1.27), v.pitch.clamp(.2, 1.1));
  }

  /// Turns the cube (animated) so the face holding [cell] faces the camera.
  void lookAt(Cell cell) {
    if (!_isCube) return;
    final face = _shape.faceOf(cell);
    if (_shape.normalOf(face).dot(_view.toViewer) > .45) return;
    // Look at the face from slightly above and to the side, so it still
    // reads as part of a cube.
    final v = _shape.normalOf(face) * 2 + const V3(.5, .5, .6);
    final target = _clamp(
      CubeView(
        math.atan2(v.y, v.x),
        math.asin((v.z / v.length).clamp(-1.0, 1.0)),
      ),
    );
    // Turn the short way round.
    var dy = target.yaw - _view.yaw;
    while (dy > math.pi) {
      dy -= 2 * math.pi;
    }
    while (dy < -math.pi) {
      dy += 2 * math.pi;
    }
    _turnFrom = _view;
    _turnTo = CubeView(_view.yaw + dy, target.pitch);
    _turn.forward(from: 0);
  }

  /// Jumps the camera to show [cell]'s face at once (tests use this to reach
  /// arrows on the back of the cube).
  @visibleForTesting
  void showNow(Cell cell) {
    lookAt(cell);
    if (_turn.isAnimating) {
      _turn.stop();
      setState(() => _view = _turnTo);
    }
  }

  void _onTurn() {
    final t = Curves.easeInOutCubic.transform(_turn.value);
    setState(() {
      _view = CubeView(
        lerpDouble(_turnFrom.yaw, _turnTo.yaw, t)!,
        lerpDouble(_turnFrom.pitch, _turnTo.pitch, t)!,
      );
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    _zoomAtStart = _zoom;
    _turn.stop();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        _zoom = (_zoomAtStart * d.scale).clamp(1.0, 3.0);
      } else {
        const speed = .011;
        _view = _clamp(
          CubeView(
            _view.yaw - d.focalPointDelta.dx * speed,
            _view.pitch + d.focalPointDelta.dy * speed,
          ),
        );
      }
    });
  }

  // ------------------------------------------------------------ geometry

  double get _cellPx => widget.cellSize * (_isCube ? _zoom : 1);

  Offset _toScreen(V3 p) {
    final pt = _shape.project(p, _view);
    if (!_isCube) return Offset(pt.x, pt.y) * widget.cellSize;
    final (w, h) = _shape.extent;
    return Offset(
      (pt.x - w / 2) * _cellPx + _box.width / 2,
      (pt.y - h / 2) * _cellPx + _box.height / 2,
    );
  }

  bool _faceShown(int face) => face < 0 || _shape.faceVisible(face, _view);

  /// Where the centre of [cell] is drawn, relative to this widget.
  @visibleForTesting
  Offset positionOf(Cell cell) => _toScreen(_shape.center3(cell));

  /// Whether [cell]'s face is turned towards the camera.
  @visibleForTesting
  bool isShown(Cell cell) => _faceShown(_shape.faceOf(cell));

  // ---------------------------------------------------------------- input

  void _handleTap(TapUpDetails details) {
    final controller = widget.controller;
    if (controller.status != GameStatus.playing) return;

    final arrow = _hitTest(details.localPosition);
    if (arrow == null) return;
    // An arrow that is still bouncing back can't be tapped again yet.
    if (_motions.containsKey(arrow.id)) return;

    final result = controller.tap(arrow);
    if (result == null) return;

    _startTicker();
    if (result is Escaped) {
      final distance = result.exitSteps + arrow.length + 2.0;
      _motions[arrow.id] = _Motion(
        arrow: arrow,
        escape: true,
        distance: distance,
        duration: Duration(
          milliseconds: (180 + distance * 28).clamp(260, 900).round(),
        ),
        startedAt: _now,
        shape: _shape,
      );
    } else if (result is Blocked) {
      // Stop with the arrow tip just touching the blocker's line.
      final distance = result.freeSteps + 0.40;
      _motions[arrow.id] = _Motion(
        arrow: arrow,
        escape: false,
        distance: distance,
        duration: Duration(
          milliseconds: (260 + distance * 70).clamp(300, 900).round(),
        ),
        startedAt: _now,
        shape: _shape,
      );
      _flashUntil[arrow.id] = _now + _motions[arrow.id]!.duration + _flash;
    }
    widget.onMove?.call(result);
  }

  /// Arrow under [position], or the nearest one within reach of a finger.
  /// Arrows on faces turned away can't be tapped.
  ArrowPath? _hitTest(Offset position) {
    ArrowPath? best;
    var bestDistance = double.infinity;
    for (final arrow in widget.controller.board.arrows) {
      if (!_faceShown(_shape.faceOf(arrow.head))) continue;
      for (final c in arrow.cells) {
        final d = (positionOf(c) - position).distance;
        if (d < bestDistance) {
          bestDistance = d;
          best = arrow;
        }
      }
    }
    return bestDistance <= _cellPx * .75 ? best : null;
  }

  // -------------------------------------------------------------- drawing

  List<_Stroke> _strokes() {
    final controller = widget.controller;
    final palette = widget.palette;
    final strokes = <_Stroke>[];

    for (final arrow in controller.board.arrows) {
      final motion = _motions[arrow.id];
      final flashing = _flashUntil.containsKey(arrow.id);
      var color = palette.arrow;
      if (flashing) {
        color = palette.error;
        final until = _flashUntil[arrow.id]!;
        final left = (until - _now).inMicroseconds / _flash.inMicroseconds;
        if (left < 1) color = Color.lerp(palette.arrow, palette.error, left)!;
      } else if (controller.hintArrowId == arrow.id) {
        color = Color.lerp(palette.hint, palette.arrow, _pulse.value * .45)!;
      }

      if (motion != null && !motion.escape) {
        final t = motion.t(_now);
        // Out and back: fast approach, quick recoil.
        final shift = t < .5
            ? Curves.easeOutCubic.transform(t * 2) * motion.distance
            : Curves.easeInOutCubic.transform((1 - t) * 2) * motion.distance;
        strokes.add(_Stroke(motion.track, arrow.length, shift, color, 1));
      } else {
        strokes.add(
          _Stroke(buildTrack(_shape, arrow, 0), arrow.length, 0, color, 1),
        );
      }
    }

    for (final motion in _motions.values) {
      if (!motion.escape) continue;
      final t = motion.t(_now);
      final shift = Curves.easeInCubic.transform(t) * motion.distance;
      final opacity = t < .7 ? 1.0 : (1 - (t - .7) / .3);
      final color = controller.hintArrowId == motion.arrow.id
          ? palette.hint
          : palette.arrow;
      strokes.add(
        _Stroke(motion.track, motion.arrow.length, shift, color, opacity),
      );
    }
    return strokes;
  }

  Widget _paint() => AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: _box,
          painter: _BoardPainter(
            shape: _shape,
            cellPx: _cellPx,
            toScreen: _toScreen,
            faceShown: _faceShown,
            palette: widget.palette,
            strokes: _strokes(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final (w, h) = _shape.extent;
    if (!_isCube) {
      _box = Size(w * widget.cellSize, h * widget.cellSize);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleTap,
        child: _paint(),
      );
    }
    // A cube uses all the room it gets, so it can grow when zoomed in.
    return LayoutBuilder(
      builder: (context, constraints) {
        _box = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : w * widget.cellSize,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : h * widget.cellSize,
        );
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTap,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: _paint(),
          ),
        );
      },
    );
  }
}

/// The route an arrow follows, with a point every half cell: its body from
/// tail to head, then [extra] more cells straight ahead. On a cube the lane
/// bends over the cube's edge; past the edge of the board the route carries
/// on in a straight line.
List<TrackPoint> buildTrack(BoardShape shape, ArrowPath arrow, int extra) {
  final face = shape.faceOf(arrow.tail);
  final points = [TrackPoint(shape.center3(arrow.cells.first), face)];
  for (var i = 1; i < arrow.cells.length; i++) {
    final prev = arrow.cells[i - 1];
    final cur = arrow.cells[i];
    points
      ..add(TrackPoint(shape.edge3(prev, Dir.between(prev, cur)), face))
      ..add(TrackPoint(shape.center3(cur), face));
  }
  var cell = arrow.head;
  var dir = arrow.direction;
  var steps = 0;
  for (final (next, nextDir) in shape.laneSteps(arrow.head, arrow.direction)) {
    if (steps >= extra) break;
    points
      ..add(TrackPoint(shape.edge3(cell, dir), shape.faceOf(cell)))
      ..add(TrackPoint(shape.center3(next), shape.faceOf(next)));
    cell = next;
    dir = nextDir;
    steps++;
  }
  if (steps < extra) {
    // Off the board: fly on in the direction of travel.
    points.add(TrackPoint(shape.edge3(cell, dir), shape.faceOf(cell)));
    final last = points.last.p - points[points.length - 2].p;
    final step = last * (.5 / last.length);
    for (var i = 0; i < (extra - steps) * 2 + 2; i++) {
      points.add(TrackPoint(points.last.p + step, -1));
    }
  }
  return points;
}

class _Stroke {
  const _Stroke(this.track, this.length, this.shift, this.color, this.opacity);

  final List<TrackPoint> track;
  final int length;
  final double shift;
  final Color color;
  final double opacity;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.shape,
    required this.cellPx,
    required this.toScreen,
    required this.faceShown,
    required this.palette,
    required this.strokes,
  });

  final BoardShape shape;
  final double cellPx;
  final Offset Function(V3) toScreen;
  final bool Function(int face) faceShown;
  final BoardPalette palette;
  final List<_Stroke> strokes;

  /// Light from above and a little to the front.
  static const _light = V3(.35, .45, .82);

  @override
  void paint(Canvas canvas, Size size) {
    // Cube faces that face the camera, shaded so the box reads as 3D.
    final corners = shape.faceCorners;
    for (var i = 0; i < corners.length; i++) {
      if (!faceShown(i)) continue;
      final path = Path()
        ..addPolygon([for (final p in corners[i]) toScreen(p)], true);
      final lit = (shape.normalOf(i).dot(_light) + 1) / 2;
      canvas
        ..drawPath(
          path,
          Paint()
            ..color = Color.lerp(palette.faceDark, palette.faceLight, lit)!,
        )
        ..drawPath(
          path,
          Paint()
            ..color = palette.faceEdge
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, cellPx * .04)
            ..strokeJoin = StrokeJoin.round,
        );
    }

    final dotPaint = Paint()..color = palette.dot;
    final dotRadius = math.max(1.2, cellPx * .055);
    for (final c in shape.cells) {
      if (!faceShown(shape.faceOf(c))) continue;
      canvas.drawCircle(toScreen(shape.center3(c)), dotRadius, dotPaint);
    }

    for (final s in strokes) {
      _paintArrow(canvas, s);
    }
  }

  /// Point at arc length [d] cells along [track] (points are half a cell
  /// apart).
  static V3 _at(List<TrackPoint> track, double d) {
    final h = d * 2;
    final i = h.floor().clamp(0, track.length - 2);
    final f = (h - i).clamp(0.0, 1.0);
    return track[i].p + (track[i + 1].p - track[i].p) * f;
  }

  void _paintArrow(Canvas canvas, _Stroke s) {
    if (s.opacity <= 0) return;
    final track = s.track;
    final start = s.shift;
    final end = s.shift + (s.length - 1);

    // The arrow's polyline, with the face each stretch lies on.
    final lastSeg = math.min((end * 2 - 1e-6).floor(), track.length - 2);
    final pts = <V3>[_at(track, start)];
    final faces = <int>[];
    for (var i = (start * 2).floor() + 1;
        i < end * 2 && i < track.length;
        i++) {
      pts.add(track[i].p);
      faces.add(track[i].face);
    }
    pts.add(_at(track, end));
    faces.add(track[lastSeg + 1].face);

    // Split it into the stretches on faces that face the camera.
    final runs = <List<Offset>>[];
    var run = <Offset>[];
    for (var k = 0; k < faces.length; k++) {
      if (faceShown(faces[k])) {
        if (run.isEmpty) run.add(toScreen(pts[k]));
        run.add(toScreen(pts[k + 1]));
      } else if (run.isNotEmpty) {
        runs.add(run);
        run = [];
      }
    }
    if (run.isNotEmpty) runs.add(run);
    if (runs.isEmpty) return;
    final headShown = faceShown(faces.last);

    final stroke = math.max(2.0, cellPx * .11);
    final color = s.color;
    // Fade body and head together so their overlap doesn't darken.
    final fading = s.opacity < 1;
    if (fading) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, s.opacity),
      );
    }
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset? tipPx, basePx, axis;
    if (headShown) {
      final along = toScreen(track[lastSeg + 1].p) - toScreen(track[lastSeg].p);
      if (along.distance > 1e-6) {
        axis = along / along.distance;
        tipPx = runs.last.last + axis * (cellPx * .26);
        basePx = tipPx - axis * (cellPx * .36);
      }
    }

    for (var r = 0; r < runs.length; r++) {
      final line = runs[r];
      final withHead = r == runs.length - 1 && basePx != null;
      final body = Path()..moveTo(line.first.dx, line.first.dy);
      for (var i = 1; i < line.length - (withHead ? 1 : 0); i++) {
        body.lineTo(line[i].dx, line[i].dy);
      }
      if (withHead) body.lineTo(basePx.dx, basePx.dy);
      canvas.drawPath(body, bodyPaint);
    }

    if (tipPx != null && basePx != null && axis != null) {
      final headHalf = cellPx * .21;
      final normal = Offset(-axis.dy, axis.dx);
      final head = Path()
        ..moveTo(tipPx.dx, tipPx.dy)
        ..lineTo(
          basePx.dx + normal.dx * headHalf,
          basePx.dy + normal.dy * headHalf,
        )
        ..lineTo(
          lerpDouble(basePx.dx, tipPx.dx, .12)!,
          lerpDouble(basePx.dy, tipPx.dy, .12)!,
        )
        ..lineTo(
          basePx.dx - normal.dx * headHalf,
          basePx.dy - normal.dy * headHalf,
        )
        ..close();
      canvas
        ..drawPath(
          head,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..strokeJoin = StrokeJoin.round,
        )
        ..drawPath(
          head,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * .45
            ..strokeJoin = StrokeJoin.round,
        );
    }
    if (fading) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
