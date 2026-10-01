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

  double w0 = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    w0 = w;
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
    if (boarded != null) {
      final area = _seats(canvas, w, h);
      _arrow(
        canvas,
        area.center,
        min(area.width, area.height) * 0.75,
        overSeats: true,
      );
    }
  }

  /// Open-top seat map: two columns, passengers as little heads.
  /// Open-top cabin with a fixed seat for every passenger: two columns of
  /// light seats, each showing a little passenger once someone boards.
  Rect _seats(Canvas canvas, double w, double h) {
    final rows = kind.seats ~/ 2;
    final top = h * (kind == VehicleKind.car ? 0.3 : 0.15);
    final bottom = h * (kind == VehicleKind.car ? 0.86 : 0.92);
    final area = Rect.fromLTRB(w * 0.17, top, w * 0.83, bottom);
    final floor = RRect.fromRectAndRadius(area, Radius.circular(w * 0.12));
    canvas.drawRRect(floor, Paint()..color = Palette.shade(color, -0.12));
    canvas.drawRRect(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, w * 0.03)
        ..color = Palette.shade(color, -0.26),
    );
    final cw = area.width / 2, ch = area.height / rows;
    final sw = cw * 0.72, sh = min(ch * 0.78, sw * 1.05);
    final seat = Paint()..color = const Color(0xFFFFFBF2);
    final seatBack = Paint()..color = const Color(0xFFE4DDCF);
    for (var k = 0; k < kind.seats; k++) {
      final c = Offset(
        area.left + cw * (k % 2 + 0.5),
        area.top + ch * (k ~/ 2 + 0.5),
      );
      final r = Rect.fromCenter(center: c, width: sw, height: sh);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(sw * 0.25)),
        seat,
      );
      // Backrest at the rear of the seat.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left, r.bottom - sh * 0.28, sw, sh * 0.28),
          Radius.circular(sw * 0.2),
        ),
        seatBack,
      );
      if (k < boarded!) {
        final hr = min(sw, sh) * 0.4;
        final head = c - Offset(0, sh * 0.06);
        canvas.drawCircle(
          head,
          hr,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: [
                Palette.shade(color, 0.25),
                color,
                Palette.shade(color, -0.2),
              ],
              stops: const [0, 0.6, 1],
            ).createShader(Rect.fromCircle(center: head, radius: hr)),
        );
        canvas.drawCircle(
          head + Offset(-hr * 0.35, -hr * 0.35),
          hr * 0.25,
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
      }
    }
    return area;
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

  void _arrow(Canvas canvas, Offset c, double s, {bool overSeats = false}) {
    if (!arrow || (boarded != null && !overSeats)) return;
    if (overSeats) {
      // Round white badge so the direction reads clearly over the seats.
      final r = min(s * 0.5, w0 * 0.3);
      canvas.drawCircle(
        c + Offset(0, r * 0.12),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, r * 0.12)
          ..color = Palette.shade(color, -0.2),
      );
      final a = r * 1.25;
      final p = Path()
        ..moveTo(c.dx, c.dy - a * 0.5)
        ..lineTo(c.dx + a * 0.42, c.dy)
        ..lineTo(c.dx + a * 0.15, c.dy)
        ..lineTo(c.dx + a * 0.15, c.dy + a * 0.45)
        ..lineTo(c.dx - a * 0.15, c.dy + a * 0.45)
        ..lineTo(c.dx - a * 0.15, c.dy)
        ..lineTo(c.dx - a * 0.42, c.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = Palette.shade(color, -0.22));
      return;
    }
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

/// A little toy-figure passenger in a solid colour, seen from slightly
/// above: rounded body with arms, head with a shine, soft ground shadow.
class PassengerPainter extends CustomPainter {
  final Color color;

  /// 0..1 walking phase; swings the arms and lifts the body a touch.
  final double step;

  PassengerPainter(this.color, {this.step = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final lift = sin(step * pi * 2).abs() * h * 0.04;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.93),
        width: w * (0.72 - lift / h),
        height: h * 0.12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.save();
    canvas.translate(0, -lift);

    final light = Palette.shade(color, 0.16);
    final dark = Palette.shade(color, -0.18);

    // Arms.
    final swing = sin(step * pi * 2) * w * 0.05;
    final arm = Paint()..color = dark;
    for (final (x, s) in [(w * 0.17, swing), (w * 0.83, -swing)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, h * 0.62 + s),
            width: w * 0.15,
            height: h * 0.26,
          ),
          Radius.circular(w * 0.08),
        ),
        arm,
      );
    }
    // Body.
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.22, h * 0.42, w * 0.56, h * 0.48),
      topLeft: Radius.circular(w * 0.26),
      topRight: Radius.circular(w * 0.26),
      bottomLeft: Radius.circular(w * 0.18),
      bottomRight: Radius.circular(w * 0.18),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, dark],
        ).createShader(body.outerRect),
    );
    // Head.
    final head = Offset(w / 2, h * 0.26);
    final hr = w * 0.22;
    canvas.drawCircle(
      head,
      hr,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Palette.shade(color, 0.28), color, dark],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: head, radius: hr)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(-hr * 0.35, -hr * 0.4),
        width: hr * 0.6,
        height: hr * 0.35,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PassengerPainter old) =>
      old.color != color || old.step != step;
}
