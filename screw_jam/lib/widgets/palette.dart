import 'package:flutter/material.dart';

class Palette {
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

  static const plates = [
    Color(0xFFFFCC80),
    Color(0xFF90CAF9),
    Color(0xFFA5D6A7),
    Color(0xFFCE93D8),
    Color(0xFFFFAB91),
    Color(0xFF80DEEA),
    Color(0xFFFFF59D),
    Color(0xFFB0BEC5),
  ];

  static const woodLight = Color(0xFFD7A86E);
  static const woodDark = Color(0xFF8D5A2B);
  static const bgTop = Color(0xFF3E2A5C);
  static const bgBottom = Color(0xFF1B1030);
  static const accent = Color(0xFFFFB300);

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
}

/// Full-screen purple gradient used behind every screen.
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
      child: child,
    );
  }
}
