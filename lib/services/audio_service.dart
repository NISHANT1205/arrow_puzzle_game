// lib/services/audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _enabled = true;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Play slide-off sound effect
  Future<void> playSlideOff() async {
    if (!_enabled) return;
    try {
      await _audioPlayer.play(
        AssetSource('sounds/slide_off.mp3'),
        volume: 0.7,
      );
    } catch (e) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play blocked tap sound effect
  Future<void> playBlockedTap() async {
    if (!_enabled) return;
    try {
      await _audioPlayer.play(
        AssetSource('sounds/blocked_tap.mp3'),
        volume: 0.5,
      );
    } catch (e) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Play level complete sound effect
  Future<void> playLevelComplete() async {
    if (!_enabled) return;
    try {
      await _audioPlayer.play(
        AssetSource('sounds/level_complete.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Play UI tap sound effect
  Future<void> playUITap() async {
    if (!_enabled) return;
    try {
      await _audioPlayer.play(
        AssetSource('sounds/ui_tap.mp3'),
        volume: 0.4,
      );
    } catch (e) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// Stop all sounds
  Future<void> stopAll() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      // Ignore
    }
  }

  /// Dispose of audio resources
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      // Ignore
    }
  }
}
