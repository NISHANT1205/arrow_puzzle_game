import 'dart:math';

import 'package:flutter/material.dart';

class Palette {
  /// Vehicle and passenger colours.
  static const vehicles = [
    Color(0xFFF44336), // red
    Color(0xFF2196F3), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFFC107), // yellow
    Color(0xFF9C27B0), // purple
    Color(0xFFFF7A1A), // orange
    Color(0xFFFF6FB0), // pink
    Color(0xFF00BCD4), // cyan
  ];

  // Light theme ------------------------------------------------------------
  static const bgTop = Color(0xFFDDF1FF);
  static const bgBottom = Color(0xFFFFF7E6);
  static const ink = Color(0xFF2E3557);
  static const inkSoft = Color(0xFF79809E);
  static const card = Colors.white;
  static const cardBorder = Color(0xFFE3E7F2);
  static const field = Color(0xFFF2F4FA);
  static const accent = Color(0xFFFFB300);
  static const blue = Color(0xFF42A5F5);
  static const green = Color(0xFF5CBF60);
  static const pink = Color(0xFFEC407A);
  static const purple = Color(0xFF9575CD);

  // Street ----------------------------------------------------------------
  static const asphalt = Color(0xFF8E97A6);
  static const asphaltLight = Color(0xFFA3ABB8);
  static const road = Color(0xFF5F6878);
  static const grass = Color(0xFF8BD46A);
  static const grassDark = Color(0xFF6DBB4E);
  static const curb = Color(0xFFE9ECF2);

  static const avatars = [
    (Icons.directions_bus_rounded, Color(0xFFFF7043)),
    (Icons.face_rounded, Color(0xFF42A5F5)),
    (Icons.local_taxi_rounded, Color(0xFFFFB300)),
    (Icons.sports_esports_rounded, Color(0xFF66BB6A)),
    (Icons.rocket_launch_rounded, Color(0xFFAB47BC)),
    (Icons.bolt_rounded, Color(0xFF26C6DA)),
    (Icons.favorite_rounded, Color(0xFFEC407A)),
    (Icons.pets_rounded, Color(0xFF8D6E63)),
  ];

  static Color vehicle(int i) => vehicles[i % vehicles.length];

  static Color shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static List<BoxShadow> softShadow([double depth = 1]) => [
    BoxShadow(
      color: const Color(0xFF4A5A8A).withValues(alpha: 0.14),
      blurRadius: 16 * depth,
      offset: Offset(0, 6 * depth),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}

/// Light sky-to-cream background with soft clouds.
class GameBackground extends StatelessWidget {
  final Widget child;
  const GameBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.bgTop, Palette.bgBottom],
        ),
      ),
      child: CustomPaint(painter: _CloudsPainter(), child: child),
    );
  }
}

class _CloudsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(3);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (var i = 0; i < 6; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.9,
      );
      final r = 18 + rng.nextDouble() * 22;
      canvas.drawCircle(c, r, paint);
      canvas.drawCircle(c + Offset(r * 0.9, r * 0.2), r * 0.8, paint);
      canvas.drawCircle(c + Offset(-r * 0.9, r * 0.25), r * 0.7, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - r * 1.5, c.dy, r * 3.2, r * 0.9),
          Radius.circular(r * 0.45),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CloudsPainter old) => false;
}
