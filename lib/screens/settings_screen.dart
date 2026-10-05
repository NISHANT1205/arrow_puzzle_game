import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progress_provider.dart';
import '../state/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Sound effects'),
            value: settings.soundEnabled,
            onChanged: notifier.setSoundEnabled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Haptics'),
            value: settings.hapticsEnabled,
            onChanged: notifier.setHapticsEnabled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark theme'),
            value: settings.darkMode,
            onChanged: notifier.setDarkMode,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Reset progress'),
            subtitle: const Text('Start again from level 1'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset progress?'),
                  content: const Text('You will go back to level 1.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(progressProvider.notifier).resetProgress();
              }
            },
          ),
        ],
      ),
    );
  }
}
