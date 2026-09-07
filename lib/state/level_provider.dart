// lib/state/level_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level.dart';
import '../services/level_repository.dart';

// Load all levels
final levelsProvider = FutureProvider<List<Level>>((ref) async {
  final repository = LevelRepository();
  return repository.loadLevels();
});

// Get all pack names
final packsProvider = FutureProvider<List<String>>((ref) async {
  final repository = LevelRepository();
  return repository.getAllPacks();
});

// Get levels for a specific pack
final levelsByPackProvider =
    FutureProvider.family<List<Level>, String>((ref, packName) async {
  final repository = LevelRepository();
  return repository.getLevelsByPack(packName);
});

// Get a specific level by ID
final levelByIdProvider = FutureProvider.family<Level?, int>((ref, id) async {
  final repository = LevelRepository();
  return repository.getLevelById(id);
});

// Track currently selected level
final selectedLevelProvider = StateProvider<Level?>((ref) => null);

// Track currently selected pack
final selectedPackProvider = StateProvider<String?>((ref) => null);

// Get next level
final nextLevelProvider =
    FutureProvider.family<Level?, int>((ref, levelId) async {
  final currentLevel = await ref.watch(levelByIdProvider(levelId).future);
  if (currentLevel != null) {
    final repository = LevelRepository();
    return repository.getNextLevel(currentLevel);
  }
  return null;
});

// Get previous level
final previousLevelProvider =
    FutureProvider.family<Level?, int>((ref, levelId) async {
  final currentLevel = await ref.watch(levelByIdProvider(levelId).future);
  if (currentLevel != null) {
    final repository = LevelRepository();
    return repository.getPreviousLevel(currentLevel);
  }
  return null;
});

// Total level count
final totalLevelCountProvider = FutureProvider<int>((ref) async {
  final levels = await ref.watch(levelsProvider.future);
  return levels.length;
});
