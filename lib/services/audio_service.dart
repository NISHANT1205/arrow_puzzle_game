// lib/services/audio_service.dart
//
// Lightweight sound effects using the platform's built-in system sounds, so
// the game ships without audio assets or extra plugins.

import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  bool _enabled = true;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  Future<void> _play(SystemSoundType type) async {
    if (!_enabled) return;
    try {
      await SystemSound.play(type);
    } catch (_) {
      // Unsupported platform: stay silent.
    }
  }

  Future<void> playSlideOff() => _play(SystemSoundType.click);

  Future<void> playBlockedTap() => _play(SystemSoundType.alert);

  Future<void> playLevelComplete() => _play(SystemSoundType.alert);

  Future<void> playUITap() => _play(SystemSoundType.click);
}
