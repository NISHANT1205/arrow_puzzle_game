// lib/state/progress_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage_service.dart';
import '../services/level_repository.dart';
import '../services/backend_sync_service.dart';

/// Player progress: the highest level reached in the curated campaign.
class Progress {
  const Progress({this.currentLevel = 1, this.levelsCleared = 0});

  /// Highest unlocked level; "Play" starts here.
  final int currentLevel;

  /// Total number of level wins, replays included.
  final int levelsCleared;
}

class ProgressNotifier extends StateNotifier<Progress> {
  ProgressNotifier() : super(const Progress()) {
    _load();
  }

  final LocalStorageService _storage = LocalStorageService();

  Future<void> _load() async {
    state = Progress(
      currentLevel:
          _clampLevel(await _storage.loadInt('current_level', defaultValue: 1)),
      levelsCleared: await _storage.loadInt('levels_cleared'),
    );
  }

  int _clampLevel(int level) {
    final count = LevelRepository.instance.bundledCount;
    return count > 0 ? level.clamp(1, count) : level;
  }

  /// Records a win on [level] and unlocks the next one.
  Future<void> completeLevel(int level) async {
    final next =
        level + 1 > state.currentLevel ? level + 1 : state.currentLevel;
    state = Progress(
        currentLevel: _clampLevel(next),
        levelsCleared: state.levelsCleared + 1);
    final best = await _storage.loadInt('backend_best_level');
    await _storage.saveInt('backend_best_level', level > best ? level : best);
    await _storage.saveInt('current_level', state.currentLevel);
    await _storage.saveInt('levels_cleared', state.levelsCleared);
  }

  Future<void> resetProgress() async {
    BackendSyncService.instance.record("reset", {});
    state = const Progress();
    await _storage.saveInt('current_level', 1);
    await _storage.saveInt('levels_cleared', 0);
  }
}

final progressProvider = StateNotifierProvider<ProgressNotifier, Progress>(
    (ref) => ProgressNotifier());
