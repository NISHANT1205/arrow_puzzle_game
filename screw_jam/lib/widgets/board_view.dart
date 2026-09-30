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
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Palette.woodLight, Color(0xFFC08A50)],
              ),
              border: Border.all(color: Palette.woodDark, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 14,
                  offset: Offset(0, 6),
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
                  children: _layers(level, cell, h),
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
    final size = cell * 0.62;
    final isHint = controller.hintScrew == i;
    Widget w = ScrewIcon(
      color: Palette.screw(s.color),
      size: size,
      glow: isHint,
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

class PlatePainter extends CustomPainter {
  final Color color;
  final List<Offset> holes;
  final double cell;

  PlatePainter(this.color, this.holes, this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    final inset = cell * 0.07;
    final rect = (Offset.zero & size).deflate(inset);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.3));
    canvas.drawRRect(
      rr.shift(Offset(0, cell * 0.08)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final hsl = HSLColor.fromColor(color);
    final dark = hsl
        .withLightness((hsl.lightness - 0.25).clamp(0, 1))
        .toColor();
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: 0.9),
            color.withValues(alpha: 0.86),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cell * 0.05)
        ..color = dark,
    );
    for (final h in holes) {
      canvas.drawCircle(
        h,
        cell * 0.24,
        Paint()..color = dark.withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        h,
        cell * 0.19,
        Paint()..color = const Color(0xFF3B2A1A).withValues(alpha: 0.75),
      );
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
