import 'dart:math';

import 'package:flutter/material.dart';

/// Draws a screw head seen from above with a Phillips slot.
class ScrewPainter extends CustomPainter {
  final Color color;
  final double angle;
  final bool glow;

  ScrewPainter(this.color, {this.angle = 0.6, this.glow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (glow) {
      canvas.drawCircle(
        c,
        r * 1.25,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(
      c + Offset(0, r * 0.12),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    final hsl = HSLColor.fromColor(color);
    final dark = hsl.withLightness((hsl.lightness - 0.2).clamp(0, 1)).toColor();
    final light = hsl
        .withLightness((hsl.lightness + 0.2).clamp(0, 1))
        .toColor();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [light, color, dark],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = dark,
    );
    final slot = Paint()
      ..color = dark
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round;
    final d = r * 0.5;
    for (final a in [angle, angle + pi / 2]) {
      final o = Offset(cos(a) * d, sin(a) * d);
      canvas.drawLine(c - o, c + o, slot);
    }
  }

  @override
  bool shouldRepaint(ScrewPainter old) =>
      old.color != color || old.angle != angle || old.glow != glow;
}

class ScrewIcon extends StatelessWidget {
  final Color color;
  final double size;
  final bool glow;
  const ScrewIcon({
    super.key,
    required this.color,
    required this.size,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: ScrewPainter(color, glow: glow),
  );
}
