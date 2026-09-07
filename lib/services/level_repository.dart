// lib/services/level_repository.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/level.dart';

class LevelRepository {
  static final LevelRepository _instance = LevelRepository._internal();

  factory LevelRepository() {
    return _instance;
  }

  LevelRepository._internal();

  List<Level>? _cachedLevels;

  /// Load all levels from assets/data/levels.json
  Future<List<Level>> loadLevels() async {
    if (_cachedLevels != null) {
      return _cachedLevels!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/levels.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _cachedLevels = jsonList
          .map((json) => Level.fromJson(json as Map<String, dynamic>))
          .toList();

      return _cachedLevels!;
    } catch (e) {
      throw Exception('Failed to load levels: $e');
    }
  }

  /// Get a specific level by ID.
  Future<Level?> getLevelById(int id) async {
    final levels = await loadLevels();
    try {
      return levels.firstWhere((level) => level.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get all levels for a specific pack.
  Future<List<Level>> getLevelsByPack(String packName) async {
    final levels = await loadLevels();
    return levels.where((level) => level.pack == packName).toList();
  }

  /// Get all unique pack names in order.
  Future<List<String>> getAllPacks() async {
    final levels = await loadLevels();
    final packs = <String>[];
    for (final level in levels) {
      if (!packs.contains(level.pack)) {
        packs.add(level.pack);
      }
    }
    return packs;
  }

  /// Get next level after the given level.
  Future<Level?> getNextLevel(Level currentLevel) async {
    final levels = await loadLevels();
    final currentIndex = levels.indexWhere((l) => l.id == currentLevel.id);
    if (currentIndex >= 0 && currentIndex < levels.length - 1) {
      return levels[currentIndex + 1];
    }
    return null;
  }

  /// Get previous level before the given level.
  Future<Level?> getPreviousLevel(Level currentLevel) async {
    final levels = await loadLevels();
    final currentIndex = levels.indexWhere((l) => l.id == currentLevel.id);
    if (currentIndex > 0) {
      return levels[currentIndex - 1];
    }
    return null;
  }

  /// Get total number of levels.
  Future<int> getTotalLevelCount() async {
    final levels = await loadLevels();
    return levels.length;
  }
}
