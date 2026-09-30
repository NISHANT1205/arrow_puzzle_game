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
        painter: PlatePainter(Palette.plate(p), holes, cell, seed: p),
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

/// A colour-stained wooden plank with grain along its length, a visible
/// edge thickness and drilled, countersunk screw holes.
class PlatePainter extends CustomPainter {
  final Color color;
  final List<Offset> holes;
  final double cell;
  final int seed;

  PlatePainter(this.color, this.holes, this.cell, {this.seed = 0});

  static const _rawWood = Color(0xFFDDB27A);

  @override
  void paint(Canvas canvas, Size size) {
    final inset = cell * 0.06;
    final rect = (Offset.zero & size).deflate(inset);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22));
    // Stain soaks into the wood: mix the paint colour with raw timber.
    final stain = Color.lerp(color, _rawWood, 0.28)!;
    final dark = Palette.shade(stain, -0.2);

    // Cast shadow on the board below.
    canvas.drawRRect(
      rr.shift(Offset(cell * 0.06, cell * 0.13)),
      Paint()
        ..color = const Color(0xFF5D3A17).withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08),
    );
    // Plank thickness.
    canvas.drawRRect(
      rr.shift(Offset(0, cell * 0.07)),
      Paint()..color = Palette.shade(stain, -0.26),
    );

    // Body, slightly see-through so buried bolts are faintly visible.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.shade(stain, 0.08).withValues(alpha: 0.9),
            stain.withValues(alpha: 0.88),
            Palette.shade(stain, -0.05).withValues(alpha: 0.9),
          ],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(rr);
    _grain(canvas, rect, dark);
    // Rounded top edge: light along the top, shade along the bottom.
    canvas.drawRRect(
      rr.shift(Offset(0, cell * 0.04)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.07
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      rr.shift(Offset(0, -cell * 0.04)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06
        ..color = dark.withValues(alpha: 0.45),
    );
    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, cell * 0.035)
        ..color = Palette.shade(stain, -0.3),
    );

    for (final h in holes) {
      paintWoodHole(canvas, h, cell * 0.25, stain);
    }
  }

  void _grain(Canvas canvas, Rect rect, Color dark) {
    final horizontal = rect.width >= rect.height;
    final length = horizontal ? rect.width : rect.height;
    final across = horizontal ? rect.height : rect.width;
    Offset at(double u, double v) => horizontal
        ? Offset(rect.left + u, rect.top + v)
        : Offset(rect.left + v, rect.top + u);

    final rng = Random(seed * 7919 + (rect.width * 13 + rect.height).round());
    final lines = max(5, (across / (cell * 0.12)).round());
    for (var i = 0; i < lines; i++) {
      final v0 = (i + rng.nextDouble()) / lines * across;
      final amp = cell * (0.02 + rng.nextDouble() * 0.06);
      final freq = (1.5 + rng.nextDouble() * 2.5) / length * pi;
      final phase = rng.nextDouble() * pi * 2;
      final path = Path();
      for (double u = -4; u <= length + 4; u += 4) {
        final o = at(u, v0 + sin(u * freq + phase) * amp);
        u < 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      final light = rng.nextDouble() < 0.3;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * (0.012 + rng.nextDouble() * 0.03)
          ..color = light
              ? Colors.white.withValues(alpha: 0.16)
              : dark.withValues(alpha: 0.18 + rng.nextDouble() * 0.2),
      );
    }

    // Occasional knot with rings that the grain bends around.
    if (length > cell * 1.6 && rng.nextDouble() < 0.7) {
      final c = at(
        length * (0.25 + rng.nextDouble() * 0.5),
        across * (0.3 + rng.nextDouble() * 0.4),
      );
      final kw = cell * 0.22, kh = cell * 0.11;
      for (var k = 3; k >= 0; k--) {
        final r = Rect.fromCenter(
          center: c,
          width: (horizontal ? kw : kh) * (1 + k * 0.6),
          height: (horizontal ? kh : kw) * (1 + k * 0.6),
        );
        canvas.drawOval(
          r,
          Paint()
            ..style = k == 0 ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = cell * 0.018
            ..color = dark.withValues(alpha: k == 0 ? 0.55 : 0.3),
        );
      }
    }
  }

  static void paintWoodHole(Canvas canvas, Offset c, double r, Color stain) {
    // Countersink: bare wood exposed by the drill.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFB98A55), Color.lerp(stain, _rawWood, 0.6)!],
          stops: const [0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final inner = r * 0.68;
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.15, 0.35),
          colors: const [Color(0xFF5A3A1E), Color(0xFF2A1A0C)],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );
    // Lit lower lip of the hole.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: inner),
      0.2,
      pi - 0.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.1)
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(PlatePainter old) =>
      old.color != color ||
      old.cell != cell ||
      old.seed != seed ||
      old.holes.length != holes.length;
}

/// A single drilled hole in wood, centred in its box.
class WoodHolePainter extends CustomPainter {
  final Color stain;
  WoodHolePainter(this.stain);

  @override
  void paint(Canvas canvas, Size size) => PlatePainter.paintWoodHole(
    canvas,
    size.center(Offset.zero),
    size.shortestSide / 2,
    stain,
  );

  @override
  bool shouldRepaint(WoodHolePainter old) => old.stain != stain;
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
