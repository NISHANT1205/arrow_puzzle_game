import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/haptic_service.dart';
import 'services/level_repository.dart';
import 'services/local_storage_service.dart';
import 'state/settings_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/first_launch_name_prompt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService().init();
  try {
    await LevelRepository.instance.preload();
  } catch (_) {
    // The game screen loads (and reports) levels on demand.
  }
  final storage = LocalStorageService();
  final settings = AppSettings(
    soundEnabled:
        await storage.loadBoolSetting('sound_enabled', defaultValue: true),
    hapticsEnabled:
        await storage.loadBoolSetting('haptics_enabled', defaultValue: true),
    darkMode: await storage.loadBoolSetting('dark_mode', defaultValue: false),
  );
  AudioService().setEnabled(settings.soundEnabled);
  await AudioService().initialize();
  runApp(ProviderScope(
    overrides: [
      settingsProvider
          .overrideWith((ref) => SettingsNotifier(initialSettings: settings))
    ],
    child: const ArrowPuzzleApp(),
  ));
  unawaited(BackendSyncService.instance.start());
}

class ArrowPuzzleApp extends ConsumerWidget {
  const ArrowPuzzleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);
    AudioService().setEnabled(ref.watch(soundEnabledProvider));
    HapticService().setEnabled(ref.watch(hapticsEnabledProvider));

    return MaterialApp(
      title: 'Arrow Puzzle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const FirstLaunchNamePrompt(child: HomeScreen()),
    );
  }
}
