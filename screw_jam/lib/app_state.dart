import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart';
import 'services/level_repository.dart';
import 'services/progress_service.dart';

/// App-wide state: signed-in user, their progress, settings and levels.
class AppState extends ChangeNotifier {
  final AuthService auth;
  final ProgressService progressService;
  final LevelRepository levels;

  UserProfile? user;
  Progress progress = Progress();

  AppState._(this.auth, this.progressService, this.levels) {
    user = auth.currentUser;
    if (user != null) progress = progressService.load(user!.username);
  }

  static Future<AppState> create({LevelRepository? levels}) async {
    final prefs = await SharedPreferences.getInstance();
    return AppState._(
      AuthService(prefs),
      ProgressService(prefs),
      levels ?? await LevelRepository.load(),
    );
  }

  bool get sound => progressService.sound;
  bool get haptics => progressService.haptics;

  void _setUser(UserProfile u) {
    user = u;
    progress = progressService.load(u.username);
    notifyListeners();
  }

  Future<void> signUp(String name, String pass, int avatar) async =>
      _setUser(await auth.signUp(name, pass, avatar: avatar));

  Future<void> login(String name, String pass) async =>
      _setUser(await auth.login(name, pass));

  Future<void> continueAsGuest() async =>
      _setUser(await auth.continueAsGuest());

  Future<void> logout() async {
    await auth.logout();
    user = null;
    progress = Progress();
    notifyListeners();
  }

  Future<void> setAvatar(int avatar) async {
    final u = user;
    if (u == null || u.isGuest) return;
    await auth.setAvatar(u.username, avatar);
    user = UserProfile(
      username: u.username,
      displayName: u.displayName,
      avatar: avatar,
    );
    notifyListeners();
  }

  Future<void> _save() async {
    if (user != null) await progressService.save(user!.username, progress);
    notifyListeners();
  }

  /// The level the Play button should open.
  int get currentLevel => min(progress.unlocked, levels.count);

  Future<void> recordPlay() async {
    progress.plays++;
    await _save();
  }

  /// Stores a win and returns the coins earned.
  Future<int> recordWin(int level, int stars) async {
    final prev = progress.stars[level] ?? 0;
    progress.stars[level] = max(prev, stars);
    progress.wins++;
    final earned = prev == 0 ? 10 + stars * 5 : 5;
    progress.coins += earned;
    if (level >= progress.unlocked) {
      progress.unlocked = min(level + 1, levels.count);
    }
    await _save();
    return earned;
  }

  Future<bool> spend(int coins) async {
    if (progress.coins < coins) return false;
    progress.coins -= coins;
    await _save();
    return true;
  }

  Future<void> resetProgress() async {
    progress = Progress();
    await _save();
  }

  Future<void> setSound(bool v) async {
    await progressService.setSound(v);
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    await progressService.setHaptics(v);
    notifyListeners();
  }

  void click() {
    if (sound) SystemSound.play(SystemSoundType.click);
  }

  void buzz({bool heavy = false}) {
    if (!haptics) return;
    heavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
  }
}
