// lib/services/level_repository.dart
//
// Serves the curated, pre-checked campaign of 225 levels.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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
    if (number < 1 || number > bundled.length) {
      throw RangeError.range(number, 1, bundled.length, 'number');
    }
    return LevelCodec.decodeLevel(bundled[number - 1]);
  }
}
