import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/level.dart';
import 'palette.dart';

/// Top-down car, van or bus drawn facing up; rotate it to face elsewhere.
class VehiclePainter extends CustomPainter {
  final Color color;
  final VehicleKind kind;
  final bool arrow;
  final bool glow;

  /// When set, the roof shows a seat map with this many passengers aboard.
  final int? boarded;

  VehiclePainter(
    this.color,
    this.kind, {
    this.arrow = true,
    this.glow = false,
    this.boarded,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (glow) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).inflate(4),
          Radius.circular(w * 0.4),
        ),
        Paint()
          ..color = const Color(0xFFFFF59D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Ground shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.03, w * 0.9, h * 0.99),
        Radius.circular(w * 0.3),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );

    _wheels(canvas, w, h);

    final body = Rect.fromLTWH(w * 0.07, 0, w * 0.86, h);
    final frontR = Radius.circular(w * (kind == VehicleKind.bus ? 0.18 : 0.34));
    final backR = Radius.circular(w * (kind == VehicleKind.bus ? 0.14 : 0.24));
    final rr = RRect.fromRectAndCorners(
      body,
      topLeft: frontR,
      topRight: frontR,
      bottomLeft: backR,
      bottomRight: backR,
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Palette.shade(color, -0.12),
            Palette.shade(color, 0.1),
            color,
            Palette.shade(color, -0.16),
          ],
          stops: const [0, 0.25, 0.7, 1],
        ).createShader(body),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, w * 0.03)
        ..color = Palette.shade(color, -0.28),
    );

    switch (kind) {
      case VehicleKind.car:
        _car(canvas, w, h);
      case VehicleKind.van:
        _van(canvas, w, h);
      case VehicleKind.bus:
        _bus(canvas, w, h);
    }
    if (boarded != null) _seats(canvas, w, h);
  }

  /// Open-top seat map: two columns, passengers as little heads.
  void _seats(Canvas canvas, double w, double h) {
    final rows = kind.seats ~/ 2;
    final top = h * (kind == VehicleKind.car ? 0.3 : 0.16);
    final bottom = h * 0.9;
    final area = Rect.fromLTRB(w * 0.18, top, w * 0.82, bottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(w * 0.12)),
      Paint()..color = Palette.shade(color, -0.3),
    );
    final cw = area.width / 2, ch = area.height / rows;
    final r = min(cw, ch) * 0.36;
    for (var k = 0; k < kind.seats; k++) {
      final c = Offset(
        area.left + cw * (k % 2 + 0.5),
        area.top + ch * (k ~/ 2 + 0.5),
      );
      if (k < boarded!) {
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFD9B8));
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          pi,
          pi,
          true,
          Paint()..color = Palette.shade(color, -0.12),
        );
      } else {
        canvas.drawCircle(
          c,
          r * 0.8,
          Paint()..color = Colors.black.withValues(alpha: 0.22),
        );
      }
    }
  }

  void _wheels(Canvas canvas, double w, double h) {
    final tyre = Paint()..color = const Color(0xFF26272E);
    final ww = w * 0.13, wh = min(h * 0.16, w * 0.32);
    final rows = kind == VehicleKind.bus
        ? [0.14, 0.7, 0.82]
        : (kind == VehicleKind.van ? [0.15, 0.78] : [0.17, 0.7]);
    for (final f in rows) {
      for (final x in [w * 0.02, w - ww - w * 0.02]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, h * f, ww, wh),
            Radius.circular(ww * 0.4),
          ),
          tyre,
        );
      }
    }
  }

  void _glass(Canvas canvas, Path p, Rect bounds) {
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6E8FBF), Color(0xFF2B3A57)],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(p);
    canvas.drawLine(
      Offset(bounds.left + bounds.width * 0.2, bounds.bottom),
      Offset(bounds.left + bounds.width * 0.45, bounds.top),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = bounds.width * 0.08,
    );
    canvas.restore();
  }

  Path _trap(
    double top,
    double bottom,
    double topInset,
    double bottomInset,
    double w,
  ) => Path()
    ..moveTo(w * topInset, top)
    ..lineTo(w * (1 - topInset), top)
    ..lineTo(w * (1 - bottomInset), bottom)
    ..lineTo(w * bottomInset, bottom)
    ..close();

  void _lights(Canvas canvas, double w, double h) {
    final head = Paint()..color = const Color(0xFFFFF4C2);
    final r = w * 0.08;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.24, h * 0.02 + r),
        width: r * 2.2,
        height: r * 1.3,
      ),
      head,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.76, h * 0.02 + r),
        width: r * 2.2,
        height: r * 1.3,
      ),
      head,
    );
    final tail = Paint()..color = const Color(0xFFD32F2F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h - r * 1.3, r * 2, r * 0.9),
        Radius.circular(r * 0.3),
      ),
      tail,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.86 - r * 2, h - r * 1.3, r * 2, r * 0.9),
        Radius.circular(r * 0.3),
      ),
      tail,
    );
  }

  void _mirrors(Canvas canvas, double w, double y) {
    final p = Paint()..color = Palette.shade(color, -0.2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.04, y),
        width: w * 0.12,
        height: w * 0.08,
      ),
      p,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.96, y),
        width: w * 0.12,
        height: w * 0.08,
      ),
      p,
    );
  }

  void _roof(Canvas canvas, Rect r, double radius) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          colors: [Palette.shade(color, 0.16), Palette.shade(color, 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(r),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Palette.shade(color, -0.12),
    );
  }

  void _arrow(Canvas canvas, Offset c, double s) {
    if (!arrow) return;
    final p = Path()
      ..moveTo(c.dx, c.dy - s * 0.5)
      ..lineTo(c.dx + s * 0.42, c.dy - s * 0.02)
      ..lineTo(c.dx + s * 0.16, c.dy - s * 0.02)
      ..lineTo(c.dx + s * 0.16, c.dy + s * 0.48)
      ..lineTo(c.dx - s * 0.16, c.dy + s * 0.48)
      ..lineTo(c.dx - s * 0.16, c.dy - s * 0.02)
      ..lineTo(c.dx - s * 0.42, c.dy - s * 0.02)
      ..close();
    canvas.drawPath(
      p.shift(Offset(0, s * 0.05)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawPath(p, Paint()..color = Colors.white);
  }

  void _car(Canvas canvas, double w, double h) {
    // Hood shine.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.25, h * 0.05, w * 0.5, h * 0.12),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    final ws = _trap(h * 0.25, h * 0.38, 0.22, 0.14, w);
    _glass(canvas, ws, Rect.fromLTWH(w * 0.14, h * 0.25, w * 0.72, h * 0.13));
    _mirrors(canvas, w, h * 0.33);
    final roof = Rect.fromLTWH(w * 0.16, h * 0.38, w * 0.68, h * 0.38);
    _roof(canvas, roof, w * 0.14);
    final rear = _trap(h * 0.76, h * 0.86, 0.17, 0.24, w);
    _glass(canvas, rear, Rect.fromLTWH(w * 0.17, h * 0.76, w * 0.66, h * 0.1));
    _lights(canvas, w, h);
    _arrow(canvas, roof.center, min(roof.width, roof.height) * 0.8);
  }

  void _van(Canvas canvas, double w, double h) {
    final ws = _trap(h * 0.12, h * 0.23, 0.2, 0.13, w);
    _glass(canvas, ws, Rect.fromLTWH(w * 0.13, h * 0.12, w * 0.74, h * 0.11));
    _mirrors(canvas, w, h * 0.18);
    final roof = Rect.fromLTWH(w * 0.14, h * 0.24, w * 0.72, h * 0.7);
    _roof(canvas, roof, w * 0.1);
    // Side windows along the roof edge.
    final glass = Paint()..color = const Color(0xFF3A4C6E);
    for (final x in [w * 0.09, w * 0.86]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * 0.27, w * 0.05, h * 0.36),
          const Radius.circular(2),
        ),
        glass,
      );
    }
    // Roof rack.
    final rack = Paint()
      ..color = Palette.shade(color, -0.2)
      ..strokeWidth = max(1.0, w * 0.025);
    for (final f in [0.62, 0.72, 0.82]) {
      canvas.drawLine(Offset(w * 0.22, h * f), Offset(w * 0.78, h * f), rack);
    }
    _lights(canvas, w, h);
    _arrow(canvas, Offset(w / 2, h * 0.42), w * 0.55);
  }

  void _bus(Canvas canvas, double w, double h) {
    final ws = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, h * 0.025, w * 0.72, h * 0.07),
          Radius.circular(w * 0.08),
        ),
      );
    _glass(canvas, ws, Rect.fromLTWH(w * 0.14, h * 0.025, w * 0.72, h * 0.07));
    _mirrors(canvas, w, h * 0.05);
    // Window strips down both sides.
    final glass = Paint()..color = const Color(0xFF3A4C6E);
    final pillar = Paint()..color = Palette.shade(color, -0.1);
    for (final x in [w * 0.08, w * 0.85]) {
      final strip = Rect.fromLTWH(x, h * 0.12, w * 0.07, h * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(strip, const Radius.circular(2)),
        glass,
      );
      for (var k = 1; k < 6; k++) {
        final y = strip.top + strip.height * k / 6;
        canvas.drawRect(Rect.fromLTWH(x, y - 1, w * 0.07, 2), pillar);
      }
    }
    final roof = Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.64, h * 0.82);
    _roof(canvas, roof, w * 0.08);
    // White roof stripe and two AC units.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.64, h * 0.05),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    final ac = Paint()..color = const Color(0xFFE6EAF0);
    final acEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFAEB6C2);
    for (final f in [0.58, 0.78]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * f, w * 0.44, h * 0.12),
        Radius.circular(w * 0.06),
      );
      canvas.drawRRect(r, ac);
      canvas.drawRRect(r, acEdge);
    }
    _lights(canvas, w, h);
    _arrow(canvas, Offset(w / 2, h * 0.34), w * 0.55);
  }

  @override
  bool shouldRepaint(VehiclePainter old) =>
      old.color != color ||
      old.kind != kind ||
      old.arrow != arrow ||
      old.glow != glow ||
      old.boarded != boarded;
}

/// A cheerful round passenger seen from the front.
class PassengerPainter extends CustomPainter {
  final Color color;
  PassengerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.94),
        width: w * 0.8,
        height: h * 0.12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.16, h * 0.42, w * 0.68, h * 0.52),
      topLeft: Radius.circular(w * 0.34),
      topRight: Radius.circular(w * 0.34),
      bottomLeft: Radius.circular(w * 0.12),
      bottomRight: Radius.circular(w * 0.12),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [Palette.shade(color, 0.12), Palette.shade(color, -0.12)],
        ).createShader(body.outerRect),
    );
    final head = Offset(w / 2, h * 0.27);
    final hr = w * 0.24;
    canvas.drawCircle(head, hr, Paint()..color = const Color(0xFFFFD9B8));
    // Hair cap in the passenger colour.
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: hr),
      pi,
      pi,
      true,
      Paint()..color = Palette.shade(color, -0.18),
    );
    final eye = Paint()..color = const Color(0xFF2E3557);
    canvas.drawCircle(head + Offset(-hr * 0.38, hr * 0.25), hr * 0.13, eye);
    canvas.drawCircle(head + Offset(hr * 0.38, hr * 0.25), hr * 0.13, eye);
  }

  @override
  bool shouldRepaint(PassengerPainter old) => old.color != color;
}
