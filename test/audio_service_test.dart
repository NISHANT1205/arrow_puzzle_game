import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/services/audio_service.dart';

class FakeSoundEngine implements SoundEngine {
  final active = <int>{};
  final played = <GameSound>[];
  final stopped = <int>[];
  int next = 1;
  int initializations = 0;
  int peakVoices = 0;
  double volume = 1;
  bool failPlay = false;
  Completer<void>? gate;
  @override
  Future<void> initialize() async {
    initializations++;
    await gate?.future;
  }

  @override
  int play(GameSound sound) {
    if (failPlay) throw StateError('device interruption');
    final handle = next++;
    active.add(handle);
    played.add(sound);
    if (active.length > peakVoices) peakVoices = active.length;
    return handle;
  }

  @override
  bool isPlaying(int handle) => active.contains(handle);
  @override
  void stop(int handle) {
    active.remove(handle);
    stopped.add(handle);
  }

  @override
  void setVolume(double value) {
    volume = value;
  }
}

void main() {
  test('1000 rapid taps play immediately with bounded voices and no queue',
      () async {
    final engine = FakeSoundEngine();
    final audio = AudioService.forTesting(engine);
    await audio.initialize(observeLifecycle: false);
    for (var i = 0; i < 1000; i++) {
      audio.playSlideOff();
    }
    expect(engine.played.length, 1000);
    expect(engine.peakVoices, AudioService.maxVoices);
    expect(engine.active.length, AudioService.maxVoices);
    audio.stopAll();
    await Future<void>.delayed(Duration.zero);
    expect(engine.active, isEmpty);
    expect(engine.played.length, 1000);
  });
  test(
      'no delayed playback while initialization is pending; initialization is shared',
      () async {
    final engine = FakeSoundEngine()..gate = Completer<void>();
    final audio = AudioService.forTesting(engine);
    final first = audio.initialize(observeLifecycle: false);
    final second = audio.initialize(observeLifecycle: false);
    audio.playUITap();
    engine.gate!.complete();
    await Future.wait([first, second]);
    expect(engine.initializations, 1);
    expect(engine.played, isEmpty);
    audio.playUITap();
    expect(engine.played, [GameSound.ui]);
  });
  test('mute stops existing effects and unmute does not replay old taps',
      () async {
    final engine = FakeSoundEngine();
    final audio = AudioService.forTesting(engine);
    await audio.initialize(observeLifecycle: false);
    audio.playSlideOff();
    audio.setEnabled(false);
    expect(engine.active, isEmpty);
    expect(engine.volume, 0);
    for (var i = 0; i < 50; i++) {
      audio.playSlideOff();
    }
    audio.setEnabled(true);
    expect(engine.played.length, 1);
    audio.playBlockedTap();
    expect(engine.played.last, GameSound.blocked);
  });
  test('background stops voices and returning does not resume stale effects',
      () async {
    final engine = FakeSoundEngine();
    final audio = AudioService.forTesting(engine);
    await audio.initialize(observeLifecycle: false);
    audio.playHint();
    audio.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(engine.active, isEmpty);
    expect(engine.volume, 0);
    audio.playSlideOff();
    audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(engine.played, [GameSound.hint]);
    expect(engine.volume, 1);
  });
  test(
      'win cue clears rapid taps and playback errors do not block future sounds',
      () async {
    final engine = FakeSoundEngine();
    final audio = AudioService.forTesting(engine);
    await audio.initialize(observeLifecycle: false);
    for (var i = 0; i < 20; i++) {
      audio.playSlideOff();
    }
    audio.playLevelComplete();
    expect(engine.active.length, 1);
    expect(engine.played.last, GameSound.win);
    engine.failPlay = true;
    audio.playUITap();
    expect(audio.playbackFailures, 1);
    engine.failPlay = false;
    audio.playUITap();
    expect(engine.played.last, GameSound.ui);
  });
}
