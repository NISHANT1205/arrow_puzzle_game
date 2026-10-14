// ignore_for_file: experimental_member_use
// Mixer capture is used only by this diagnostic, never by the game.
// Run on a real device or simulator:
// flutter run -t tool/audio_smoke.dart -d <device>
// Captures native mixer PCM to verify actual output during rapid taps.
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:arrow_puzzle/services/audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Audio stress check…')))));
  final audio = AudioService();
  await audio.initialize();
  if (!audio.isReady) throw StateError('Audio did not initialize');
  final engine = SoLoud.instance;
  var peak = 0.0;
  var peakVoices = 0;
  var totalFrames = 0;
  final subscription =
      engine.startMixerOutputStream().listen((Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 4 <= bytes.length; i += 4) {
      final sample = data.getFloat32(i, Endian.little).abs();
      if (sample > peak) peak = sample;
      totalFrames++;
    }
  });
  final stopwatch = Stopwatch()..start();
  var maxDispatchMicros = 0;
  for (var i = 0; i < 200; i++) {
    final before = stopwatch.elapsedMicroseconds;
    if (i % 5 == 0) {
      audio.playBlockedTap();
    } else {
      audio.playSlideOff();
    }
    final elapsed = stopwatch.elapsedMicroseconds - before;
    if (elapsed > maxDispatchMicros) maxDispatchMicros = elapsed;
    final voices = engine.getActiveVoiceCount();
    if (voices > peakVoices) peakVoices = voices;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  audio.playLevelComplete();
  await Future<void>.delayed(const Duration(milliseconds: 700));
  final burstPeak = peak;
  final burstFrames = totalFrames;
  audio.setEnabled(false);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  peak = 0;
  for (var i = 0; i < 20; i++) {
    audio.playSlideOff();
  }
  await Future<void>.delayed(const Duration(milliseconds: 150));
  final mutedPeak = peak;
  audio.setEnabled(true);
  peak = 0;
  audio.playRevive();
  await Future<void>.delayed(const Duration(milliseconds: 450));
  final resumedPeak = peak;
  audio.didChangeAppLifecycleState(AppLifecycleState.paused);
  audio.playSlideOff();
  audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  final remaining = engine.getActiveVoiceCount();
  engine.stopMixerOutputStream();
  await subscription.cancel();
  final passed = burstPeak > .001 &&
      burstFrames > 0 &&
      mutedPeak < .0001 &&
      resumedPeak > .001 &&
      remaining == 0 &&
      audio.playbackFailures == 0 &&
      peakVoices <= AudioService.maxVoices;
  final result = 'AUDIO_STRESS_${passed ? "PASS" : "FAIL"}: 200 taps/10ms, '
      'peak=$burstPeak, voices=$peakVoices, dispatchMax=${maxDispatchMicros}us, '
      'muted=$mutedPeak, resumed=$resumedPeak, remaining=$remaining, '
      'failures=${audio.playbackFailures}';
  debugPrint(result);
  runApp(MaterialApp(
      home: Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24), child: Text(result))))));
  if (!passed) throw StateError(result);
}
