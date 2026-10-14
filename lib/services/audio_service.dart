import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

enum GameSound { ui, slide, blocked, hint, win, lose, revive }

/// Small injectable boundary so burst handling can be tested without a device.
abstract interface class SoundEngine {
  Future<void> initialize();
  int play(GameSound sound);
  bool isPlaying(int handle);
  void stop(int handle);
  void setVolume(double volume);
}

class _SoLoudEngine implements SoundEngine {
  final Map<GameSound, AudioSource> _sources = {};
  SoLoud get _engine => SoLoud.instance;

  @override
  Future<void> initialize() async {
    await _engine.init(sampleRate: 44100, bufferSize: 512);
    _engine.setMaxActiveVoiceCount(16);
    try {
      for (final sound in GameSound.values) {
        _sources[sound] =
            await _engine.loadAsset('assets/audio/${sound.name}.wav');
      }
    } catch (_) {
      _sources.clear();
      _engine.deinit();
      rethrow;
    }
  }

  @override
  int play(GameSound sound) {
    final handle = _engine.play(_sources[sound]!, volume: .25);
    if (handle.isError || !_engine.getIsValidVoiceHandle(handle)) {
      throw StateError('Audio voice did not start');
    }
    return handle.id;
  }

  @override
  bool isPlaying(int handle) =>
      _engine.getIsValidVoiceHandle(SoundHandle(handle));

  @override
  void stop(int handle) {
    // Native stop happens immediately; completion only waits for cleanup.
    unawaited(_engine.stop(SoundHandle(handle)).catchError((Object error) {
      debugPrint('Audio stop failed: $error');
    }));
  }

  @override
  void setVolume(double volume) => _engine.setGlobalVolume(volume);
}

/// Preloaded, immediate effects with bounded polyphony and no playback queue.
class AudioService with WidgetsBindingObserver {
  AudioService._(this._engine);
  static final _instance = AudioService._(_SoLoudEngine());
  factory AudioService() => _instance;
  @visibleForTesting
  AudioService.forTesting(SoundEngine engine) : _engine = engine;

  final SoundEngine _engine;
  final List<int> _voices = [];
  static const maxVoices = 8;
  Future<void>? _initializing;
  bool _ready = false;
  bool _enabled = true;
  bool _foreground = true;
  bool _observing = false;
  int _failures = 0;
  bool get isReady => _ready;
  int get playbackFailures => _failures;

  Future<void> initialize({bool observeLifecycle = true}) {
    if (_ready) return Future.value();
    return _initializing ??= _initialize(observeLifecycle);
  }

  Future<void> _initialize(bool observeLifecycle) async {
    try {
      await _engine.initialize();
      _ready = true;
      _engine.setVolume(_enabled && _foreground ? 1 : 0);
      if (observeLifecycle && !_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
    } catch (error) {
      debugPrint('Game audio initialization failed: $error');
    } finally {
      _initializing = null;
    }
  }

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!_ready) return;
    _engine.setVolume(_enabled && _foreground ? 1 : 0);
    if (!enabled) stopAll();
  }

  void stopAll() {
    for (final handle in _voices) {
      if (_engine.isPlaying(handle)) _engine.stop(handle);
    }
    _voices.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_ready) {
      if (_foreground) unawaited(initialize());
      return;
    }
    _engine.setVolume(_enabled && _foreground ? 1 : 0);
    // Do not resume old effects after returning from the background.
    if (!_foreground) stopAll();
  }

  void _play(GameSound sound, {bool priority = false}) {
    if (!_enabled || !_foreground || !_ready) return;
    try {
      _voices.removeWhere((handle) => !_engine.isPlaying(handle));
      if (priority) stopAll();
      while (_voices.length >= maxVoices) {
        _engine.stop(_voices.removeAt(0));
      }
      _voices.add(_engine.play(sound));
    } catch (error) {
      _failures++;
      debugPrint('Game audio playback failed: $error');
    }
  }

  void playSlideOff() => _play(GameSound.slide);
  void playBlockedTap() => _play(GameSound.blocked);
  void playLevelComplete() => _play(GameSound.win, priority: true);
  void playGameOver() => _play(GameSound.lose, priority: true);
  void playHint() => _play(GameSound.hint);
  void playRevive() => _play(GameSound.revive, priority: true);
  void playUITap() => _play(GameSound.ui);
}
