import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/palette.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: GameBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('Sound'),
              secondary: const Icon(Icons.volume_up_rounded),
              value: app.sound,
              onChanged: app.setSound,
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              secondary: const Icon(Icons.vibration_rounded),
              value: app.haptics,
              onChanged: app.setHaptics,
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.help_outline_rounded),
              title: Text('How to play'),
              subtitle: Text(
                'Tap a vehicle to drive it out of the lot. It can only leave if '
                'nothing is in front of it (follow the arrow on its roof). It '
                'parks at the station, and passengers of the same colour board '
                'it in queue order. A full vehicle drives off and frees its bay. '
                'Board everyone to win; if every bay is full and the front '
                'passenger cannot board, you lose.',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
              ),
              title: const Text('Reset progress'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset progress?'),
                    content: const Text(
                      'All stars, coins and unlocked levels for this profile will be lost.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await app.resetProgress();
                  if (context.mounted) showToast(context, 'Progress reset');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
