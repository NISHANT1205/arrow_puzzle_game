// lib/state/settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

/// User settings
class AppSettings {
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool darkMode;

  const AppSettings({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.darkMode = false,
  });

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? darkMode,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

/// Notifier for app settings
class SettingsNotifier extends StateNotifier<AppSettings> {
  final LocalStorageService _storage = LocalStorageService();

  SettingsNotifier() : super(const AppSettings()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final soundEnabled =
        await _storage.loadBoolSetting('sound_enabled', defaultValue: true);
    final hapticsEnabled =
        await _storage.loadBoolSetting('haptics_enabled', defaultValue: true);
    final darkMode =
        await _storage.loadBoolSetting('dark_mode', defaultValue: false);

    state = AppSettings(
      soundEnabled: soundEnabled,
      hapticsEnabled: hapticsEnabled,
      darkMode: darkMode,
    );
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _storage.saveBoolSetting('sound_enabled', enabled);
    state = state.copyWith(soundEnabled: enabled);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    await _storage.saveBoolSetting('haptics_enabled', enabled);
    state = state.copyWith(hapticsEnabled: enabled);
  }

  Future<void> setDarkMode(bool enabled) async {
    await _storage.saveBoolSetting('dark_mode', enabled);
    state = state.copyWith(darkMode: enabled);
  }
}

/// Provider for app settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// Provider for sound enabled
final soundEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).soundEnabled;
});

/// Provider for haptics enabled
final hapticsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).hapticsEnabled;
});

/// Provider for dark mode
final darkModeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).darkMode;
});
