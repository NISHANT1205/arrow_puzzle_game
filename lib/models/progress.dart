// lib/models/progress.dart

import 'package:hive/hive.dart';

/// Tracks progress for a single level.
@HiveType(typeId: 0)
class LevelProgress {
  @HiveField(0)
  final int levelId;

  @HiveField(1)
  bool isCompleted;

  @HiveField(2)
  int stars; // 0-3 stars

  @HiveField(3)
  int bestMoveCount; // Minimum moves needed to clear

  @HiveField(4)
  int blockedTapCount; // Blocked taps on best attempt

  LevelProgress({
    required this.levelId,
    this.isCompleted = false,
    this.stars = 0,
    this.bestMoveCount = 999,
    this.blockedTapCount = 0,
  });

  /// Update progress with a new completion attempt.
  void updateProgress({
    required int moveCount,
    required int blockedTaps,
  }) {
    final wasCompleted = isCompleted;
    isCompleted = true;

    // Update best move count if this is better
    if (moveCount < bestMoveCount) {
      bestMoveCount = moveCount;
    }
    if (!wasCompleted || blockedTaps < blockedTapCount) {
      blockedTapCount = blockedTaps;
    }

    // Calculate stars based on blocked taps
    if (blockedTaps == 0) {
      stars = 3; // Perfect!
    } else if (blockedTaps <= 2) {
      if (stars < 2) stars = 2;
    } else {
      if (stars < 1) stars = 1;
    }
  }

  @override
  String toString() =>
      'LevelProgress(id=$levelId, completed=$isCompleted, stars=$stars, bestMoves=$bestMoveCount)';
}

/// Pack progress tracking.
class PackProgress {
  final String packName;
  final Map<int, LevelProgress> levels; // levelId -> progress

  PackProgress({
    required this.packName,
    Map<int, LevelProgress>? levels,
  }) : levels = levels ?? {};

  int getCompletedCount() => levels.values.where((p) => p.isCompleted).length;

  int getTotalLevels() => levels.length;

  int getTotalStars() => levels.values.fold(0, (sum, p) => sum + p.stars);

  bool isPackUnlocked() => getCompletedCount() > 0;
}
