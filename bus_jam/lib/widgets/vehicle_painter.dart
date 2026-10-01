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

    if (kind == VehicleKind.bus) {
      _cityBus(canvas, w, h);
      return;
    }

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
        break; // Drawn by _cityBus.
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
  Rect _seats(
    Canvas canvas,
    double w,
    double h, {
    Rect? within,
    bool glass = false,
  }) {
    final rows = kind.seats ~/ 2;
    final top = h * (kind == VehicleKind.car ? 0.3 : 0.15);
    final bottom = h * (kind == VehicleKind.car ? 0.86 : 0.92);
    final area = within ?? Rect.fromLTRB(w * 0.17, top, w * 0.83, bottom);
    final floor = RRect.fromRectAndRadius(area, Radius.circular(w * 0.12));
    canvas.drawRRect(
      floor,
      Paint()
        ..color = glass
            ? Palette.shade(color, -0.3)
            : Palette.shade(color, -0.12),
    );
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
    if (glass) {
      // Tinted skylight over the cabin with a soft diagonal reflection.
      canvas.drawRRect(
        floor,
        Paint()..color = const Color(0xFF9FD3FF).withValues(alpha: 0.14),
      );
      canvas.save();
      canvas.clipRRect(floor);
      final sheen = Path()
        ..moveTo(area.left, area.top + area.height * 0.25)
        ..lineTo(area.left + area.width * 0.55, area.top)
        ..lineTo(area.left + area.width * 0.85, area.top)
        ..lineTo(area.left, area.top + area.height * 0.42)
        ..close();
      canvas.drawPath(
        sheen,
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
      canvas.restore();
      canvas.drawRRect(
        floor,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, w * 0.035)
          ..color = const Color(0xFFB8C0CC),
      );
    }
    return area;
  }

  /// A detailed city bus seen from above.
  void _cityBus(Canvas canvas, double w, double h) {
    final dark = Palette.shade(color, -0.22);
    final tyre = Paint()..color = const Color(0xFF202127);
    final hub = Paint()..color = const Color(0xFF9AA3AE);

    // Wheels: single front axle, twin rear axles.
    final tw = w * 0.13, th = w * 0.3;
    for (final y in [h * 0.08, h * 0.68, h * 0.78]) {
      for (final x in [w * 0.005, w - tw - w * 0.005]) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, tw, th),
          Radius.circular(tw * 0.35),
        );
        canvas.drawRRect(r, tyre);
        canvas.drawRect(
          Rect.fromLTWH(x + tw * 0.3, y + th * 0.3, tw * 0.4, th * 0.4),
          hub,
        );
      }
    }

    // Body with a rounded-cylinder shade and a long specular line.
    final body = Rect.fromLTWH(w * 0.06, 0, w * 0.88, h);
    final rr = RRect.fromRectAndCorners(
      body,
      topLeft: Radius.circular(w * 0.18),
      topRight: Radius.circular(w * 0.18),
      bottomLeft: Radius.circular(w * 0.12),
      bottomRight: Radius.circular(w * 0.12),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          colors: [
            dark,
            Palette.shade(color, 0.12),
            color,
            Palette.shade(color, -0.2),
          ],
          stops: const [0, 0.22, 0.6, 1],
        ).createShader(body),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, w * 0.03)
        ..color = Palette.shade(color, -0.32),
    );

    // Front: bumper, lights, wide curved windshield with wipers.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, 0, w * 0.72, h * 0.012),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = const Color(0xFF2C2E35),
    );
    final head = Paint()..color = const Color(0xFFFFF6CF);
    final amber = Paint()..color = const Color(0xFFFFA726);
    for (final x in [w * 0.13, w * 0.73]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * 0.006, w * 0.14, h * 0.014),
          Radius.circular(w * 0.04),
        ),
        head,
      );
    }
    canvas.drawCircle(Offset(w * 0.1, h * 0.02), w * 0.035, amber);
    canvas.drawCircle(Offset(w * 0.9, h * 0.02), w * 0.035, amber);
    final ws = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.11, h * 0.024, w * 0.78, h * 0.072),
      topLeft: Radius.circular(w * 0.16),
      topRight: Radius.circular(w * 0.16),
      bottomLeft: Radius.circular(w * 0.04),
      bottomRight: Radius.circular(w * 0.04),
    );
    _glass(canvas, Path()..addRRect(ws), ws.outerRect);
    final wiper = Paint()
      ..color = const Color(0xFF1B1D22)
      ..strokeWidth = max(1.0, w * 0.025)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.3, h * 0.09),
      Offset(w * 0.45, h * 0.045),
      wiper,
    );
    canvas.drawLine(
      Offset(w * 0.6, h * 0.09),
      Offset(w * 0.75, h * 0.045),
      wiper,
    );

    // Rabbit-ear mirrors reaching forward from the front corners.
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, w * 0.035)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2C2E35);
    final mirror = Paint()..color = const Color(0xFF2C2E35);
    for (final side in [-1.0, 1.0]) {
      final x0 = side < 0 ? w * 0.1 : w * 0.9;
      final tip = Offset(x0 + side * w * 0.1, -h * 0.004);
      canvas.drawPath(
        Path()
          ..moveTo(x0, h * 0.04)
          ..quadraticBezierTo(
            x0 + side * w * 0.12,
            h * 0.035,
            tip.dx,
            tip.dy + h * 0.012,
          ),
        arm,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: tip, width: w * 0.09, height: h * 0.022),
          Radius.circular(w * 0.03),
        ),
        mirror,
      );
    }

    // Tinted window bands down both sides, split by pillars; door on the right.
    final band = h * 0.11;
    final bandLen = h * 0.8;
    final pillar = Paint()..color = Palette.shade(color, -0.12);
    for (final x in [w * 0.075, w * 0.855]) {
      final strip = Rect.fromLTWH(x, band, w * 0.07, bandLen);
      _glass(
        canvas,
        Path()
          ..addRRect(RRect.fromRectAndRadius(strip, Radius.circular(w * 0.02))),
        strip,
      );
      for (var k = 1; k < 7; k++) {
        final y = band + bandLen * k / 7;
        canvas.drawRect(
          Rect.fromLTWH(x, y - h * 0.004, w * 0.07, h * 0.008),
          pillar,
        );
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(w * 0.855, band + h * 0.01, w * 0.07, h * 0.075),
      Paint()..color = const Color(0xFF1F2A3C),
    );
    canvas.drawLine(
      Offset(w * 0.89, band + h * 0.01),
      Offset(w * 0.89, band + h * 0.085),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );

    // White roof with ribs.
    final roof = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.155, h * 0.105, w * 0.69, h * 0.86),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(
      roof,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Palette.shade(color, 0.04),
            Palette.shade(color, 0.16),
            Palette.shade(color, -0.02),
          ],
          stops: const [0, 0.4, 1],
        ).createShader(roof.outerRect),
    );
    canvas.drawRRect(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.lerp(color, Colors.black, 0.25)!.withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.155, h * 0.105, w * 0.69, h * 0.02),
        topLeft: Radius.circular(w * 0.08),
        topRight: Radius.circular(w * 0.08),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    final rib = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double y = h * 0.13; y < h * 0.95; y += h * 0.035) {
      canvas.drawLine(Offset(w * 0.17, y), Offset(w * 0.83, y), rib);
    }

    // Rear roof AC unit with fans.
    final ac = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.8, w * 0.56, h * 0.11),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(
      ac.shift(Offset(0, h * 0.006)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      ac,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF4F6F9), Color(0xFFC9D0DA)],
        ).createShader(ac.outerRect),
    );
    final fan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.02)
      ..color = const Color(0xFF8F98A5);
    final fr = min(ac.width, ac.height) * 0.26;
    for (final f in [0.33, 0.67]) {
      final c = Offset(ac.left + ac.width / 2, ac.top + ac.height * f);
      canvas.drawCircle(c, fr, fan);
      canvas.drawLine(c - Offset(fr, 0), c + Offset(fr, 0), fan);
      canvas.drawLine(c - Offset(0, fr), c + Offset(0, fr), fan);
    }

    // Rear: engine grille, bumper and tail lights.
    final grille = Paint()
      ..color = const Color(0xFF3A3D45)
      ..strokeWidth = max(1.0, h * 0.004);
    for (var k = 0; k < 3; k++) {
      final y = h * (0.925 + k * 0.012);
      canvas.drawLine(Offset(w * 0.3, y), Offset(w * 0.7, y), grille);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.988, w * 0.72, h * 0.012),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = const Color(0xFF2C2E35),
    );
    final tail = Paint()..color = const Color(0xFFD32F2F);
    for (final x in [w * 0.1, w * 0.78]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * 0.972, w * 0.12, h * 0.014),
          Radius.circular(w * 0.03),
        ),
        tail,
      );
    }

    // Long specular highlight on the left flank.
    canvas.drawLine(
      Offset(w * 0.115, h * 0.05),
      Offset(w * 0.115, h * 0.95),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = max(1.0, w * 0.025),
    );

    final cabin = Rect.fromLTWH(w * 0.2, h * 0.13, w * 0.6, h * 0.64);
    if (boarded != null) {
      _seats(canvas, w, h, within: cabin, glass: true);
      _arrow(
        canvas,
        cabin.center,
        min(cabin.width, cabin.height) * 0.75,
        overSeats: true,
      );
    } else {
      // Roof hatches and the arrow.
      final hatch = Paint()..color = Colors.black.withValues(alpha: 0.12);
      for (final f in [0.22, 0.6]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.36, h * f, w * 0.28, h * 0.07),
            Radius.circular(w * 0.04),
          ),
          hatch,
        );
      }
      _arrow(canvas, Offset(w / 2, h * 0.42), w * 0.5);
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
