import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Progress {
  int unlocked;
  int coins;
  int wins;
  int plays;
  final Map<int, int> stars;

  Progress({
    this.unlocked = 1,
    this.coins = 200,
    this.wins = 0,
    this.plays = 0,
    Map<int, int>? stars,
  }) : stars = stars ?? {};

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
    'unlocked': unlocked,
    'coins': coins,
    'wins': wins,
    'plays': plays,
    'stars': stars.map((k, v) => MapEntry('$k', v)),
  };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
    unlocked: j['unlocked'] as int? ?? 1,
    coins: j['coins'] as int? ?? 200,
    wins: j['wins'] as int? ?? 0,
    plays: j['plays'] as int? ?? 0,
    stars: ((j['stars'] as Map?) ?? {}).map(
      (k, v) => MapEntry(int.parse(k as String), v as int),
    ),
  );
}

class ProgressService {
  final SharedPreferences prefs;
  ProgressService(this.prefs);

  String _key(String user) => 'progress:$user';

  Progress load(String user) {
    final raw = prefs.getString(_key(user));
    if (raw == null) return Progress();
    return Progress.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
  }

  Future<void> save(String user, Progress p) =>
      prefs.setString(_key(user), jsonEncode(p.toJson()));

  Future<void> reset(String user) => prefs.remove(_key(user));

  bool get sound => prefs.getBool('sound') ?? true;
  bool get haptics => prefs.getBool('haptics') ?? true;
  Future<void> setSound(bool v) => prefs.setBool('sound', v);
  Future<void> setHaptics(bool v) => prefs.setBool('haptics', v);
}
