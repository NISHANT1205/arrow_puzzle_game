import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/game_state.dart';
import '../engine/level.dart';
import '../game/game_controller.dart';
import 'palette.dart';
import 'screw_painter.dart';

/// The wooden board with stacked plates and screws.
class BoardView extends StatelessWidget {
  final GameController controller;
  final ValueChanged<int> onScrewTap;

  const BoardView({
    super.key,
    required this.controller,
    required this.onScrewTap,
  });

  @override
  Widget build(BuildContext context) {
    final level = controller.level;
    return LayoutBuilder(
      builder: (context, box) {
        const pad = 10.0;
        final cell = min(
          (box.maxWidth - pad * 2) / level.cols,
          (box.maxHeight - pad * 2) / level.rows,
        );
        final w = cell * level.cols, h = cell * level.rows;
        return Center(
          child: Container(
            width: w + pad * 2,
            height: h + pad * 2,
            padding: const EdgeInsets.all(pad),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Palette.woodMid, Palette.woodDark],
              ),
              border: Border.all(color: const Color(0xFFA06A35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A4A1E).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _handleTap(d.localPosition, cell),
              child: SizedBox(
                key: const Key('board'),
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          painter: WoodBoardPainter(level.cols, level.rows),
                        ),
                      ),
                    ),
                    ..._layers(level, cell, h),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset p, double cell) {
    final state = controller.state;
    final level = controller.level;
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < level.screws.length; i++) {
      if (state.screwLoc[i] != ScrewLocation.board) continue;
      final s = level.screws[i];
      final c = Offset((s.x + 0.5) * cell, (s.y + 0.5) * cell);
      final d = (c - p).distance;
      if (d < cell * 0.6 && d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    if (best != null) onScrewTap(best);
  }

  List<Widget> _layers(LevelDef level, double cell, double boardH) {
    final state = controller.state;
    final out = <Widget>[];
    for (var p = 0; p < level.plates.length; p++) {
      final plate = level.plates[p];
      final rect = Rect.fromLTWH(
        plate.x * cell,
        plate.y * cell,
        plate.w * cell,
        plate.h * cell,
      );
      final holes = [
        for (final s in level.screws)
          if (s.plate == p)
            Offset((s.x - plate.x + 0.5) * cell, (s.y - plate.y + 0.5) * cell),
      ];
      final painter = CustomPaint(
        size: rect.size,
        painter: PlatePainter(Palette.plate(p), holes, cell),
      );
      if (state.plateAlive[p]) {
        out.add(Positioned.fromRect(rect: rect, child: painter));
        for (var i = 0; i < level.screws.length; i++) {
          final s = level.screws[i];
          if (s.plate != p || state.screwLoc[i] != ScrewLocation.board) {
            continue;
          }
          out.add(_screw(i, s, cell));
        }
      } else if (controller.fallenPlates.contains(p)) {
        out.add(
          Positioned.fromRect(
            rect: rect,
            child: IgnorePointer(
              child: _FallingPlate(
                key: ValueKey('fall-$p-${controller.stamp}'),
                distance: boardH,
                direction: p.isEven ? 1 : -1,
                child: painter,
              ),
            ),
          ),
        );
      }
    }
    return out;
  }

  Widget _screw(int i, ScrewDef s, double cell) {
    final size = cell * 0.7;
    final isHint = controller.hintScrew == i;
    Widget w = ScrewIcon(
      color: Palette.screw(s.color),
      size: size,
      glow: isHint,
      angle: (i * 0.37) % (pi / 3),
    );
    if (controller.shakeScrew == i) {
      w = TweenAnimationBuilder<double>(
        key: ValueKey('shake-$i-${controller.stamp}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        builder: (_, t, child) => Transform.translate(
          offset: Offset(sin(t * pi * 6) * (1 - t) * cell * 0.14, 0),
          child: child,
        ),
        child: w,
      );
    } else if (isHint) {
      w = _Pulse(child: w);
    }
    return Positioned(
      left: (s.x + 0.5) * cell - size / 2,
      top: (s.y + 0.5) * cell - size / 2,
      width: size,
      height: size,
      child: w,
    );
  }
}

/// Light maple pegboard with procedural grain and a grid of peg holes.
class WoodBoardPainter extends CustomPainter {
  final int cols, rows;
  WoodBoardPainter(this.cols, this.rows);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.woodLight, Color(0xFFF1D2A2), Palette.woodLight],
        ).createShader(rect),
    );
    // Grain: long, gently wavy lines.
    final rng = Random(cols * 31 + rows);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 26; i++) {
      final y0 = rng.nextDouble() * size.height;
      final amp = 2 + rng.nextDouble() * 6;
      final freq = 0.008 + rng.nextDouble() * 0.012;
      final phase = rng.nextDouble() * 6;
      grain.color = const Color(0xFFC89A62)
          .withValues(alpha: 0.12 + rng.nextDouble() * 0.16);
      final path = Path()..moveTo(0, y0);
      for (double x = 0; x <= size.width; x += 6) {
        path.lineTo(x, y0 + sin(x * freq + phase) * amp);
      }
      canvas.drawPath(path, grain);
    }
    // Knots.
    for (var i = 0; i < 2; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      for (var k = 0; k < 4; k++) {
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 14.0 + k * 10, height: 6.0 + k * 5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFB9824A).withValues(alpha: 0.18),
        );
      }
    }
    // Peg holes.
    final cell = size.width / cols;
    final hole = Paint()
      ..color = const Color(0xFFC9A375).withValues(alpha: 0.55);
    final lip = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final c = Offset((x + 0.5) * cell, (y + 0.5) * cell);
        canvas.drawCircle(c + Offset(0, cell * 0.03), cell * 0.09, lip);
        canvas.drawCircle(c, cell * 0.09, hole);
      }
    }
    // Inner vignette for depth.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            Colors.transparent,
            const Color(0xFF9C6B36).withValues(alpha: 0.16),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(WoodBoardPainter old) =>
      old.cols != cols || old.rows != rows;
}

/// A tinted, glossy acrylic plate with metal-rimmed screw holes.
class PlatePainter extends CustomPainter {
  final Color color;
  final List<Offset> holes;
  final double cell;

  PlatePainter(this.color, this.holes, this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    final inset = cell * 0.06;
    final rect = (Offset.zero & size).deflate(inset);
    final radius = Radius.circular(cell * 0.28);
    final rr = RRect.fromRectAndRadius(rect, radius);

    // Cast shadow on the board below.
    canvas.drawRRect(
      rr.shift(Offset(cell * 0.06, cell * 0.12)),
      Paint()
        ..color = const Color(0xFF5D3A17).withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08),
    );

    // Plate thickness: a darker slab peeking out below.
    canvas.drawRRect(
      rr.shift(Offset(0, cell * 0.05)),
      Paint()..color = Palette.shade(color, -0.2).withValues(alpha: 0.55),
    );

    // Translucent body so buried bolts show through faintly.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: 0.78),
            color.withValues(alpha: 0.7),
          ],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(rr);
    // Diagonal gloss band.
    final gloss = Path()
      ..moveTo(rect.left, rect.top + rect.height * 0.55)
      ..lineTo(rect.left + rect.width * 0.55, rect.top)
      ..lineTo(rect.left + rect.width * 0.75, rect.top)
      ..lineTo(rect.left, rect.top + rect.height * 0.85)
      ..close();
    canvas.drawPath(
      gloss,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    // Top bevel highlight and bottom bevel shade.
    canvas.drawRRect(
      rr.shift(Offset(0, cell * 0.035)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      rr.shift(Offset(0, -cell * 0.035)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05
        ..color = Palette.shade(color, -0.18).withValues(alpha: 0.5),
    );
    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, cell * 0.035)
        ..color = Palette.shade(color, -0.25),
    );

    for (final h in holes) {
      HolePainter.paintHole(canvas, h, cell * 0.25);
    }
  }

  @override
  bool shouldRepaint(PlatePainter old) =>
      old.color != color ||
      old.cell != cell ||
      old.holes.length != holes.length;
}

class _FallingPlate extends StatelessWidget {
  final double distance;
  final int direction;
  final Widget child;

  const _FallingPlate({
    super.key,
    required this.distance,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeIn,
      builder: (_, t, c) => Opacity(
        opacity: (1 - t).clamp(0, 1),
        child: Transform.translate(
          offset: Offset(direction * t * 30, t * distance * 0.8),
          child: Transform.rotate(angle: direction * t * 0.8, child: c),
        ),
      ),
      child: child,
    );
  }
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
    scale: Tween(begin: 0.9, end: 1.2).animate(_c),
    child: widget.child,
  );
}
