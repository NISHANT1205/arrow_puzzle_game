import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/game_state.dart';
import '../engine/level.dart';
import '../game/game_controller.dart';
import 'palette.dart';
import 'vehicle_painter.dart';

/// The parking lot: a road loop around an asphalt lot full of vehicles.
class LotView extends StatelessWidget {
  final GameController controller;
  final ValueChanged<int> onVehicleTap;

  const LotView({
    super.key,
    required this.controller,
    required this.onVehicleTap,
  });

  @override
  Widget build(BuildContext context) {
    final level = controller.level;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = min(
          box.maxWidth / (level.cols + 1.4),
          box.maxHeight / (level.rows + 1.4),
        );
        final road = cell * 0.7;
        final w = cell * level.cols, h = cell * level.rows;
        return Center(
          child: SizedBox(
            width: w + road * 2,
            height: h + road * 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: LotPainter(level.cols, level.rows, cell, road),
                  ),
                ),
                Positioned(
                  left: road,
                  top: road,
                  width: w,
                  height: h,
                  child: Stack(
                    key: const Key('lot'),
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < level.vehicles.length; i++)
                        ?_vehicle(i, cell),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Rect _rect(VehicleDef v, double cell) {
    final (tx, ty) = v.tail;
    final x0 = min(v.x, tx), y0 = min(v.y, ty);
    final x1 = max(v.x, tx), y1 = max(v.y, ty);
    return Rect.fromLTRB(
      x0 * cell,
      y0 * cell,
      (x1 + 1) * cell,
      (y1 + 1) * cell,
    );
  }

  Widget? _vehicle(int i, double cell) {
    final v = controller.level.vehicles[i];
    final state = controller.state;
    final inLot = state.loc[i] == VehicleLoc.lot;
    final leaving = controller.exiting == i && !inLot;
    if (!inLot && !leaving) return null;

    final rect = _rect(v, cell);
    Widget w = RotatedBox(
      quarterTurns: v.dir.index,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cell * 0.08,
          vertical: cell * 0.04,
        ),
        child: CustomPaint(
          painter: VehiclePainter(
            Palette.vehicle(v.color),
            v.kind,
            glow: controller.hintVehicle == i,
          ),
        ),
      ),
    );

    if (leaving) {
      // Drive straight out of the lot and past the road.
      final cells = switch (v.dir) {
        Dir.up => v.y + 1,
        Dir.down => controller.level.rows - v.y,
        Dir.left => v.x + 1,
        Dir.right => controller.level.cols - v.x,
      };
      final dist = (cells + v.length + 1) * cell;
      w = TweenAnimationBuilder<double>(
        key: ValueKey('exit-$i-${controller.stamp}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + cells * 40),
        curve: Curves.easeIn,
        builder: (_, t, child) => Opacity(
          opacity: (1 - t * t).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(v.dir.dx * dist * t, v.dir.dy * dist * t),
            child: child,
          ),
        ),
        child: w,
      );
      return Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(child: w),
      );
    }

    if (controller.bumped == i) {
      w = TweenAnimationBuilder<double>(
        key: ValueKey('bump-$i-${controller.stamp}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        builder: (_, t, child) {
          final d = sin(t * pi) * cell * 0.28;
          return Transform.translate(
            offset: Offset(v.dir.dx * d, v.dir.dy * d),
            child: child,
          );
        },
        child: w,
      );
    } else if (controller.blocker == i) {
      final b = controller.level.vehicles[controller.bumped!];
      w = TweenAnimationBuilder<double>(
        key: ValueKey('hit-$i-${controller.stamp}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        builder: (_, t, child) {
          final d = t < 0.35
              ? 0.0
              : sin((t - 0.35) * pi * 5) * (1 - t) * cell * 0.1;
          return Transform.translate(
            offset: Offset(b.dir.dx * d, b.dir.dy * d),
            child: child,
          );
        },
        child: w,
      );
    } else if (controller.hintVehicle == i) {
      w = _Pulse(child: w);
    }

    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        key: Key('veh-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onVehicleTap(i),
        child: w,
      ),
    );
  }
}

class LotPainter extends CustomPainter {
  final int cols, rows;
  final double cell, road;
  LotPainter(this.cols, this.rows, this.cell, this.road);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final lot = Rect.fromLTWH(road, road, cols * cell, rows * cell);

    // Road loop.
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, Radius.circular(road * 1.2)),
      Paint()..color = Palette.road,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.deflate(1), Radius.circular(road * 1.2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.curb,
    );
    // Dashed centre line around the loop.
    final mid = outer.deflate(road / 2);
    final dash = Paint()
      ..color = const Color(0xFFFFE082)
      ..strokeWidth = max(1.5, road * 0.07)
      ..strokeCap = StrokeCap.round;
    void dashed(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (double d = 0; d < len; d += road * 0.9) {
        canvas.drawLine(a + dir * d, a + dir * min(len, d + road * 0.45), dash);
      }
    }

    dashed(mid.topLeft, mid.topRight);
    dashed(mid.bottomLeft, mid.bottomRight);
    dashed(mid.topLeft, mid.bottomLeft);
    dashed(mid.topRight, mid.bottomRight);

    // Curb and asphalt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot.inflate(3), Radius.circular(cell * 0.25)),
      Paint()..color = Palette.curb,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot, Radius.circular(cell * 0.2)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.asphaltLight, Palette.asphalt],
        ).createShader(lot),
    );
    // Asphalt speckle.
    final rng = Random(cols * 7 + rows);
    final speck = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (var i = 0; i < cols * rows * 6; i++) {
      canvas.drawCircle(
        Offset(
          lot.left + rng.nextDouble() * lot.width,
          lot.top + rng.nextDouble() * lot.height,
        ),
        0.8 + rng.nextDouble(),
        speck,
      );
    }
    // Parking stall lines.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    for (var x = 1; x < cols; x++) {
      final px = lot.left + x * cell;
      for (var y = 0; y < rows; y++) {
        final py = lot.top + y * cell;
        canvas.drawLine(
          Offset(px, py + cell * 0.2),
          Offset(px, py + cell * 0.8),
          line,
        );
      }
    }
    for (var y = 1; y < rows; y++) {
      final py = lot.top + y * cell;
      for (var x = 0; x < cols; x++) {
        final px = lot.left + x * cell;
        canvas.drawCircle(Offset(px, py), 1.4, line);
      }
    }
  }

  @override
  bool shouldRepaint(LotPainter old) =>
      old.cols != cols || old.rows != rows || old.cell != cell;
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(begin: 0.94, end: 1.06).animate(_c),
    child: widget.child,
  );
}
