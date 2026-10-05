// lib/services/level_repository.dart
//
// Serves levels: the bundled, pre-checked levels first (each one harder than
// the one before), then endless generated levels at the hardest settings.

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../engine/level_generator.dart';
import '../models/level.dart';
import '../models/level_codec.dart';

class LevelRepository {
  LevelRepository._();

  static final LevelRepository instance = LevelRepository._();

  static const String assetPath = 'assets/levels/levels.json';

  List<Map<String, dynamic>>? _bundled;

  /// Number of bundled levels (known after the first [level] call).
  int get bundledCount => _bundled?.length ?? 0;

  /// Parses the bundled file. Exposed for tests and tools.
  static List<Map<String, dynamic>> parse(String json) => [
        for (final l in (jsonDecode(json) as Map<String, dynamic>)['levels']
            as List<dynamic>)
          l as Map<String, dynamic>,
      ];

  Future<List<Map<String, dynamic>>> _load() async =>
      _bundled ??= parse(await rootBundle.loadString(assetPath));

  /// Loads the bundled levels ahead of time (call at startup).
  Future<void> preload() => _load();

  /// Whether bundled level [number] is a 3D cube level. False until the
  /// levels are loaded.
  bool isCube(int number) {
    final bundled = _bundled;
    if (bundled == null || number < 1 || number > bundled.length) {
      return false;
    }
    return bundled[number - 1]['shape'] != null;
  }

  Future<Level> level(int number) async {
    final bundled = await _load();
    if (number >= 1 && number <= bundled.length) {
      return LevelCodec.decodeLevel(bundled[number - 1]);
    }
    try {
      // Big boards take a moment; keep the UI thread free.
      return await compute(LevelGenerator.generate, number);
    } catch (_) {
      return LevelGenerator.generate(number);
    }
  }
}
