// lib/services/local_storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/progress.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize the service (call once at app startup).
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Save progress for a level.
  Future<void> saveLevelProgress(LevelProgress progress) async {
    await _ensureInitialized();
    final key = 'level_progress_${progress.levelId}';
    final json = jsonEncode({
      'levelId': progress.levelId,
      'isCompleted': progress.isCompleted,
      'stars': progress.stars,
      'bestMoveCount': progress.bestMoveCount,
      'blockedTapCount': progress.blockedTapCount,
    });
    await _prefs.setString(key, json);
  }

  /// Load progress for a level.
  Future<LevelProgress?> loadLevelProgress(int levelId) async {
    await _ensureInitialized();
    final key = 'level_progress_$levelId';
    final json = _prefs.getString(key);
    if (json == null) return null;

    final data = jsonDecode(json) as Map<String, dynamic>;
    return LevelProgress(
      levelId: data['levelId'] as int,
      isCompleted: data['isCompleted'] as bool,
      stars: data['stars'] as int,
      bestMoveCount: data['bestMoveCount'] as int,
      blockedTapCount: data['blockedTapCount'] as int,
    );
  }

  /// Load all progress data.
  Future<Map<int, LevelProgress>> loadAllProgress() async {
    await _ensureInitialized();
    final result = <int, LevelProgress>{};
    final keys = _prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('level_progress_')) {
        final json = _prefs.getString(key);
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final progress = LevelProgress(
            levelId: data['levelId'] as int,
            isCompleted: data['isCompleted'] as bool,
            stars: data['stars'] as int,
            bestMoveCount: data['bestMoveCount'] as int,
            blockedTapCount: data['blockedTapCount'] as int,
          );
          result[progress.levelId] = progress;
        }
      }
    }

    return result;
  }

  /// Clear all progress data (for testing or reset).
  Future<void> clearAllProgress() async {
    await _ensureInitialized();
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('level_progress_')) {
        await _prefs.remove(key);
      }
    }
  }

  /// Save user settings.
  Future<void> saveBoolSetting(String key, bool value) async {
    await _ensureInitialized();
    await _prefs.setBool(key, value);
  }

  /// Load user settings.
  Future<bool> loadBoolSetting(String key, {bool defaultValue = false}) async {
    await _ensureInitialized();
    return _prefs.getBool(key) ?? defaultValue;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }
}
