// lib/services/local_storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> saveInt(String key, int value) async {
    await _ensureInitialized();
    await _prefs.setInt(key, value);
  }

  Future<int> loadInt(String key, {int defaultValue = 0}) async {
    await _ensureInitialized();
    return _prefs.getInt(key) ?? defaultValue;
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
