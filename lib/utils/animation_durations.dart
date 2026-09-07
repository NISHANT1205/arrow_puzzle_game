// lib/utils/animation_durations.dart

/// Standard animation durations for the game
class AnimationDurations {
  static const Duration slideOff = Duration(milliseconds: 300);
  static const Duration bounce = Duration(milliseconds: 150);
  static const Duration tapFeedback = Duration(milliseconds: 100);
  static const Duration boardClear = Duration(milliseconds: 500);
  static const Duration transitionPage = Duration(milliseconds: 300);
  static const Duration hintHighlight = Duration(milliseconds: 400);
}

/// Game sound effects
enum GameSound {
  slideOff('sounds/slide_off.mp3'),
  blockedTap('sounds/blocked_tap.mp3'),
  levelComplete('sounds/level_complete.mp3'),
  uiTap('sounds/ui_tap.mp3');

  final String path;
  const GameSound(this.path);
}

/// Visual feedback colors
class GameColors {
  // Arrow tile colors
  static const int arrowTileLight = 0xFFF5F5F5;
  static const int arrowTileDark = 0xFF2C2C2C;

  // Highlight colors
  static const int hintHighlight = 0xFFFDD835;
  static const int selectedTile = 0xFFBBDEFB;

  // Animation colors
  static const int slideTrail = 0xFFBBDEFB;
  static const int blockedFade = 0xFFEF5350;

  // Game states
  static const int successGreen = 0xFF4CAF50;
  static const int inProgressBlue = 0xFF2196F3;
  static const int blockedRed = 0xFFEF5350;
}

/// Haptic feedback patterns
enum HapticPattern {
  light,
  medium,
  heavy,
  tap,
  longPress;
}
