// lib/widgets/arrow_board_view.dart
//
// Draws the dot grid and every arrow, turns taps into moves and animates
// them:
//  * escape  – the arrow slithers along its own body and out of the board;
//  * blocked – the arrow creeps forward until its head bumps the arrow in the
//              way, flashes red and snaps back.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  });

  final Color arrow;
  final Color dot;
  final Color hint;
  final Color error;

  static const light = BoardPalette(
    arrow: Color(0xFF1C1F33),
    dot: Color(0xFFC9CCD8),
    hint: Color(0xFF2E90FF),
    error: Color(0xFFF03E5A),
  );

  static const dark = BoardPalette(
    arrow: Color(0xFFEDEFF7),
    dot: Color(0xFF3D4257),
    hint: Color(0xFF4DA3FF),
    error: Color(0xFFFF5470),
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
  State<ArrowBoardView> createState() => _ArrowBoardViewState();
}

class _Motion {
  _Motion({
    required this.arrow,
    required this.escape,
    required this.distance,
    required this.duration,
    required this.startedAt,
  }) : track = buildTrack(arrow, distance.ceil() + 1);

  final ArrowPath arrow;
  final bool escape;

  /// How far (in cells) the head travels: out of the board for an escape,
  /// up to the blocker for a bump.
  final double distance;
  final Duration duration;
  final Duration startedAt;
  final List<Offset> track;

  double t(Duration now) {
    final elapsed = (now - startedAt).inMicroseconds / duration.inMicroseconds;
    return elapsed.clamp(0.0, 1.0);
  }

  bool isDone(Duration now) => t(now) >= 1;
}

class _ArrowBoardViewState extends State<ArrowBoardView>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _pulse;
  Duration _now = Duration.zero;
  final Map<int, _Motion> _motions = {};

  /// Arrows that recently bumped, mapped to when the red flash ends.
  final Map<int, Duration> _flashUntil = {};
  static const _flash = Duration(milliseconds: 650);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // A restart puts every arrow back; drop animations of the old run.
    if (widget.controller.moves == 0 && _motions.isNotEmpty) {
      _motions.clear();
      _flashUntil.clear();
    }
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
      );
      _flashUntil[arrow.id] = _now + _motions[arrow.id]!.duration + _flash;
    }
    widget.onMove?.call(result);
  }

  /// Arrow under [position], or the nearest one within reach of a finger.
  ArrowPath? _hitTest(Offset position) {
    final cell = widget.cellSize;
    final col = (position.dx / cell).floor();
    final row = (position.dy / cell).floor();
    final direct = widget.controller.arrowAt(Cell(row, col));
    if (direct != null) return direct;

    ArrowPath? best;
    var bestDistance = double.infinity;
    for (var r = row - 1; r <= row + 1; r++) {
      for (var c = col - 1; c <= col + 1; c++) {
        final arrow = widget.controller.arrowAt(Cell(r, c));
        if (arrow == null) continue;
        final centre = Offset((c + .5) * cell, (r + .5) * cell);
        final d = (centre - position).distance;
        if (d < bestDistance) {
          bestDistance = d;
          best = arrow;
        }
      }
    }
    return bestDistance <= cell * .85 ? best : null;
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
        strokes.add(_Stroke(buildTrack(arrow, 0), arrow.length, 0, color, 1));
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final size = Size(
      controller.level.cols * widget.cellSize,
      controller.level.rows * widget.cellSize,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: size,
          painter: _BoardPainter(
            rows: controller.level.rows,
            cols: controller.level.cols,
            cellSize: widget.cellSize,
            dotColor: widget.palette.dot,
            strokes: _strokes(),
          ),
        ),
      ),
    );
  }
}

/// The route an arrow follows, in cell units (cell centres): its body from
/// tail to head, then [extra] more cells straight ahead.
List<Offset> buildTrack(ArrowPath arrow, int extra) {
  final dir = arrow.direction;
  return [
    for (final c in arrow.cells) Offset(c.col + .5, c.row + .5),
    for (var i = 1; i <= extra; i++)
      Offset(arrow.head.col + .5 + dir.dCol * i,
          arrow.head.row + .5 + dir.dRow * i),
  ];
}

class _Stroke {
  const _Stroke(this.track, this.length, this.shift, this.color, this.opacity);

  final List<Offset> track;
  final int length;
  final double shift;
  final Color color;
  final double opacity;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.dotColor,
    required this.strokes,
  });

  final int rows;
  final int cols;
  final double cellSize;
  final Color dotColor;
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = dotColor;
    final dotRadius = math.max(1.2, cellSize * .055);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset((c + .5) * cellSize, (r + .5) * cellSize),
          dotRadius,
          dotPaint,
        );
      }
    }

    for (final s in strokes) {
      _paintArrow(canvas, s);
    }
  }

  /// Point at arc length [d] along [track] (each segment is one cell long).
  static Offset _at(List<Offset> track, double d) {
    final i = d.floor().clamp(0, track.length - 2);
    final f = (d - i).clamp(0.0, 1.0);
    return Offset.lerp(track[i], track[i + 1], f)!;
  }

  void _paintArrow(Canvas canvas, _Stroke s) {
    if (s.opacity <= 0) return;
    final track = s.track;
    final start = s.shift;
    final end = s.shift + (s.length - 1);

    final points = <Offset>[_at(track, start)];
    for (var i = start.floor() + 1; i < end && i < track.length; i++) {
      if (i > start) points.add(track[i]);
    }
    final tip = _at(track, end);
    points.add(tip);

    final segment = math.min((end - 1e-6).floor(), track.length - 2);
    final axis = track[segment + 1] - track[segment];

    final px = [for (final p in points) p * cellSize];
    final stroke = math.max(2.0, cellSize * .11);
    final color = s.color;
    // Fade body and head together so their overlap doesn't darken.
    final fading = s.opacity < 1;
    if (fading) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, s.opacity),
      );
    }

    final headLength = cellSize * .36;
    final headHalf = cellSize * .21;
    final tipPx = px.last + axis * (cellSize * .26);
    final basePx = tipPx - axis * headLength;

    final body = Path()..moveTo(px.first.dx, px.first.dy);
    for (var i = 1; i < px.length - 1; i++) {
      body.lineTo(px[i].dx, px[i].dy);
    }
    body.lineTo(basePx.dx, basePx.dy);

    canvas.drawPath(
      body,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final normal = Offset(-axis.dy, axis.dx);
    final head = Path()
      ..moveTo(tipPx.dx, tipPx.dy)
      ..lineTo(
          basePx.dx + normal.dx * headHalf, basePx.dy + normal.dy * headHalf)
      ..lineTo(
        lerpDouble(basePx.dx, tipPx.dx, .12)!,
        lerpDouble(basePx.dy, tipPx.dy, .12)!,
      )
      ..lineTo(
          basePx.dx - normal.dx * headHalf, basePx.dy - normal.dy * headHalf)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * .45
        ..strokeJoin = StrokeJoin.round,
    );
    if (fading) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
