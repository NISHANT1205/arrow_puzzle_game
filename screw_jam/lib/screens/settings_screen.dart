import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/palette.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Palette.bgTop,
      ),
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
                'Tap a screw to unscrew it. It flies into the open box of the '
                'same colour, or into the tray if no box matches. A plate falls '
                'when all its screws are out. Screws under another plate are '
                'stuck until that plate is gone. Fill every box to win; if the '
                'tray fills up and nothing can move, you lose.',
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
