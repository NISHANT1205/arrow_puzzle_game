import 'dart:math';

import 'package:flutter/material.dart';

class Palette {
  /// Bolt head colours, one per box colour.
  static const screws = [
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFDD835), // yellow
    Color(0xFF8E24AA), // purple
    Color(0xFFFB8C00), // orange
    Color(0xFFFF80AB), // pink
    Color(0xFF00ACC1), // teal
    Color(0xFF8D6E63), // brown
  ];

  static const screwNames = [
    'Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange', 'Pink', 'Teal', //
    'Brown',
  ];

  /// Tinted acrylic plate colours.
  static const plates = [
    Color(0xFFFFB74D),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFBA68C8),
    Color(0xFFFF8A65),
    Color(0xFF4DD0E1),
    Color(0xFFFFD54F),
    Color(0xFF90A4AE),
  ];

  // Light theme ------------------------------------------------------------
  static const bgTop = Color(0xFFE3F2FD);
  static const bgBottom = Color(0xFFFFF8E7);
  static const ink = Color(0xFF34305A);
  static const inkSoft = Color(0xFF7C7898);
  static const card = Colors.white;
  static const cardBorder = Color(0xFFE7E3F3);
  static const field = Color(0xFFF4F2FA);
  static const accent = Color(0xFFFFB300);
  static const blue = Color(0xFF42A5F5);
  static const green = Color(0xFF5CBF60);
  static const pink = Color(0xFFEC407A);
  static const purple = Color(0xFF9575CD);

  // Wood and metal ---------------------------------------------------------
  static const woodLight = Color(0xFFF6DEB6);
  static const woodMid = Color(0xFFEBC48E);
  static const woodDark = Color(0xFFB9824A);
  static const steelLight = Color(0xFFF5F7FA);
  static const steelMid = Color(0xFFC9D1DA);
  static const steelDark = Color(0xFF8A96A3);

  static const avatars = [
    (Icons.pets_rounded, Color(0xFFFF7043)),
    (Icons.face_rounded, Color(0xFF42A5F5)),
    (Icons.rocket_launch_rounded, Color(0xFFAB47BC)),
    (Icons.sports_esports_rounded, Color(0xFF66BB6A)),
    (Icons.emoji_nature_rounded, Color(0xFFFFCA28)),
    (Icons.bolt_rounded, Color(0xFF26C6DA)),
    (Icons.favorite_rounded, Color(0xFFEC407A)),
    (Icons.star_rounded, Color(0xFF8D6E63)),
  ];

  static Color screw(int i) => screws[i % screws.length];
  static Color plate(int i) => plates[i % plates.length];

  static Color shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static List<BoxShadow> softShadow([double depth = 1]) => [
    BoxShadow(
      color: const Color(0xFF6B5FA8).withValues(alpha: 0.14),
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

/// Light sky-to-cream background with a few soft bubbles.
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
      child: CustomPaint(painter: _BubblesPainter(), child: child),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    const colors = [
      Color(0xFFBBDEFB),
      Color(0xFFFFE0B2),
      Color(0xFFE1BEE7),
      Color(0xFFC8E6C9),
    ];
    for (var i = 0; i < 9; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final r = 30 + rng.nextDouble() * 70;
      canvas.drawCircle(
        c,
        r,
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => false;
}
