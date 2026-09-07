// lib/state/progress_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress.dart';
import '../services/local_storage_service.dart';

/// Notifier for progress tracking
class ProgressNotifier extends StateNotifier<Map<int, LevelProgress>> {
  final LocalStorageService _storage = LocalStorageService();

  ProgressNotifier() : super({}) {
    _initialize();
  }

  Future<void> _initialize() async {
    final progress = await _storage.loadAllProgress();
    state = progress;
  }

  /// Save progress for a level
  Future<void> saveLevelProgress(
      int levelId, int moveCount, int blockedTaps) async {
    final existingProgress = state[levelId];
    final progress = LevelProgress(
      levelId: levelId,
      isCompleted: existingProgress?.isCompleted ?? false,
      stars: existingProgress?.stars ?? 0,
      bestMoveCount: existingProgress?.bestMoveCount ?? 999,
      blockedTapCount: existingProgress?.blockedTapCount ?? 0,
    );

    progress.updateProgress(
      moveCount: moveCount,
      blockedTaps: blockedTaps,
    );

    await _storage.saveLevelProgress(progress);
    state = {...state, levelId: progress};
  }

  /// Get progress for a level
  LevelProgress getProgress(int levelId) {
    return state[levelId] ?? LevelProgress(levelId: levelId);
  }

  /// Check if a level is completed
  bool isLevelCompleted(int levelId) {
    return state[levelId]?.isCompleted ?? false;
  }

  /// Get stars for a level
  int getStars(int levelId) {
    return state[levelId]?.stars ?? 0;
  }

  /// Get total stars across all levels
  int getTotalStars() {
    return state.values.fold(0, (sum, p) => sum + p.stars);
  }

  /// Get total completed levels
  int getTotalCompleted() {
    return state.values.where((p) => p.isCompleted).length;
  }

  /// Check if a pack is unlocked (at least one level completed)
  bool isPackUnlocked(List<int> packLevelIds) {
    return packLevelIds.any((id) => isLevelCompleted(id));
  }

  /// Clear all progress
  Future<void> clearAllProgress() async {
    await _storage.clearAllProgress();
    state = {};
  }
}

/// Provider for progress tracking
final progressProvider =
    StateNotifierProvider<ProgressNotifier, Map<int, LevelProgress>>((ref) {
  return ProgressNotifier();
});

/// Provider to get progress for a specific level
final levelProgressProvider =
    Provider.family<LevelProgress, int>((ref, levelId) {
  final progressMap = ref.watch(progressProvider);
  return progressMap[levelId] ?? LevelProgress(levelId: levelId);
});

/// Provider to get stars for a specific level
final levelStarsProvider = Provider.family<int, int>((ref, levelId) {
  final progress = ref.watch(levelProgressProvider(levelId));
  return progress.stars;
});

/// Provider to check if a level is completed
final isLevelCompletedProvider = Provider.family<bool, int>((ref, levelId) {
  final progress = ref.watch(levelProgressProvider(levelId));
  return progress.isCompleted;
});

/// Provider for total stars count
final totalStarsProvider = Provider<int>((ref) {
  final progressMap = ref.watch(progressProvider);
  return progressMap.values.fold(0, (sum, p) => sum + p.stars);
});

/// Provider for total completed levels
final totalCompletedProvider = Provider<int>((ref) {
  final progressMap = ref.watch(progressProvider);
  return progressMap.values.where((p) => p.isCompleted).length;
});

/// Provider to check if a pack is unlocked
final isPackUnlockedProvider =
    Provider.family<bool, List<int>>((ref, levelIds) {
  final progressMap = ref.watch(progressProvider);
  return levelIds.any((id) => progressMap[id]?.isCompleted ?? false);
});
