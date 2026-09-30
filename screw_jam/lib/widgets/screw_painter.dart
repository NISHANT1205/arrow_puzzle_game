import 'dart:math';

import 'package:flutter/material.dart';

import 'palette.dart';

/// A coloured hex bolt seen from above: chrome washer, bevelled hex head
/// lit from the top-left, and a Phillips recess.
class ScrewPainter extends CustomPainter {
  final Color color;
  final double angle;
  final bool glow;

  ScrewPainter(this.color, {this.angle = 0.3, this.glow = false});

  static const _light = Offset(-0.6, -0.8); // light direction (normalised-ish)

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    if (glow) {
      canvas.drawCircle(
        c,
        r * 1.3,
        Paint()
          ..color = const Color(0xFFFFF176)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
      );
    }

    // Contact shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(r * 0.12, r * 0.2),
        width: r * 2.05,
        height: r * 1.95,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
    );

    _washer(canvas, c, r);
    _hexHead(canvas, c, r * 0.8);
  }

  void _washer(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Palette.steelLight,
            Palette.steelDark,
            Palette.steelMid,
            Palette.steelLight,
            Palette.steelDark,
            Palette.steelMid,
            Palette.steelLight,
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.05)
        ..color = const Color(0xFF6B7682),
    );
  }

  List<Offset> _hex(Offset c, double r) => [
    for (var i = 0; i < 6; i++)
      c + Offset(cos(angle + i * pi / 3) * r, sin(angle + i * pi / 3) * r),
  ];

  Path _poly(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  void _hexHead(Canvas canvas, Offset c, double r) {
    final outer = _hex(c, r);
    final inner = _hex(c, r * 0.72);
    final dark = Palette.shade(color, -0.22);
    final light = Palette.shade(color, 0.2);

    // Chamfer faces, shaded by how much each faces the light.
    for (var i = 0; i < 6; i++) {
      final a = outer[i], b = outer[(i + 1) % 6];
      final ib = inner[(i + 1) % 6], ia = inner[i];
      final mid = (a + b) / 2 - c;
      final n = mid / mid.distance;
      final lambert = (n.dx * _light.dx + n.dy * _light.dy); // -1..1
      final face = lambert >= 0
          ? Color.lerp(color, Colors.white, lambert * 0.55)!
          : Color.lerp(color, Colors.black, -lambert * 0.45)!;
      canvas.drawPath(_poly([a, b, ib, ia]), Paint()..color = face);
    }

    // Flat top with a soft gradient.
    final topRect = Rect.fromCircle(center: c, radius: r * 0.72);
    canvas.drawPath(
      _poly(inner),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, Palette.shade(color, -0.08)],
        ).createShader(topRect),
    );
    canvas.drawPath(
      _poly(outer),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.06)
        ..color = dark,
    );

    // Phillips recess: dark groove with a lit lower edge.
    final d = r * 0.42;
    final w = r * 0.2;
    for (final a in [pi / 4 + angle, 3 * pi / 4 + angle]) {
      final o = Offset(cos(a) * d, sin(a) * d);
      canvas.drawLine(
        c - o + Offset(0, w * 0.35),
        c + o + Offset(0, w * 0.35),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        c - o,
        c + o,
        Paint()
          ..color = Palette.shade(color, -0.32)
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(c, w * 0.55, Paint()..color = Palette.shade(color, -0.4));

    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.32, -r * 0.4),
        width: r * 0.55,
        height: r * 0.26,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
  }

  @override
  bool shouldRepaint(ScrewPainter old) =>
      old.color != color || old.angle != angle || old.glow != glow;
}

class ScrewIcon extends StatelessWidget {
  final Color color;
  final double size;
  final bool glow;
  final double angle;
  const ScrewIcon({
    super.key,
    required this.color,
    required this.size,
    this.glow = false,
    this.angle = 0.3,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: ScrewPainter(color, glow: glow, angle: angle),
  );
}

/// An empty threaded hole, as left behind in a plate or the tray.
class HolePainter extends CustomPainter {
  final double radius;
  final Iterable<Offset> centers;
  HolePainter(this.centers, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in centers) {
      paintHole(canvas, c, radius);
    }
  }

  static void paintHole(Canvas canvas, Offset c, double r) {
    // Brushed metal grommet.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.steelDark, Palette.steelLight],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Recess with inner shadow at the top.
    final inner = r * 0.72;
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, 0.35),
          colors: const [Color(0xFF6D6A75), Color(0xFF2E2B33)],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );
    // Thread rings.
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, r * 0.05)
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(c, inner * 0.7, thread);
    canvas.drawCircle(c, inner * 0.45, thread);
  }

  @override
  bool shouldRepaint(HolePainter old) => old.radius != radius;
}
