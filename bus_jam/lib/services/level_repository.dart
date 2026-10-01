import 'dart:convert';

import 'package:flutter/services.dart';

import '../engine/level.dart';

class LevelRepository {
  final List<LevelDef> levels;
  LevelRepository(this.levels);

  static Future<LevelRepository> load() async {
    final raw = await rootBundle.loadString('assets/levels.json');
    return LevelRepository(parse(raw));
  }

  static List<LevelDef> parse(String raw) => (jsonDecode(raw) as List)
      .map((e) => LevelDef.fromJson((e as Map).cast<String, dynamic>()))
      .toList();

  int get count => levels.length;
  LevelDef operator [](int number) => levels[number - 1];
}
