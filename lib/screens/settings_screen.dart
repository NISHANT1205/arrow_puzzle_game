import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_links.dart';
import '../services/audio_service.dart';
import '../state/progress_provider.dart';
import '../state/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openLink(BuildContext context, Uri url) async {
    AudioService().playUITap();
    final opened = await AppLinks.open(url);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open the link. Please try again.')),
      );
    }
  }

  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    AudioService().playUITap();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('You will go back to level 1.'),
        actions: [
          TextButton(
            onPressed: () {
              AudioService().playUITap();
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              AudioService().playUITap();
              Navigator.pop(context, true);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(progressProvider.notifier).resetProgress();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AudioService().playUITap();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primaryContainer, colors.surfaceContainerLow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: .75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child:
                      Icon(Icons.tune_rounded, size: 32, color: colors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Make it yours',
                        style: text.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Your puzzle. Your preferences.',
                        style: text.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 26),
            _heading(context, 'PLAY YOUR WAY'),
            _SettingsCard(children: [
              SwitchListTile(
                secondary: _SettingsIcon(
                    icon: settings.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded),
                title: const Text('Sound effects'),
                subtitle: Text(settings.soundEnabled ? 'Sound on' : 'Muted'),
                value: settings.soundEnabled,
                onChanged: notifier.setSoundEnabled,
              ),
              const Divider(height: 1, indent: 72, endIndent: 16),
              SwitchListTile(
                secondary: const _SettingsIcon(icon: Icons.vibration_rounded),
                title: const Text('Haptics'),
                subtitle: const Text('Feel each move'),
                value: settings.hapticsEnabled,
                onChanged: (value) {
                  AudioService().playUITap();
                  notifier.setHapticsEnabled(value);
                },
              ),
              const Divider(height: 1, indent: 72, endIndent: 16),
              SwitchListTile(
                secondary: const _SettingsIcon(icon: Icons.dark_mode_rounded),
                title: const Text('Dark theme'),
                subtitle: const Text('A softer glow for your puzzles'),
                value: settings.darkMode,
                onChanged: (value) {
                  AudioService().playUITap();
                  notifier.setDarkMode(value);
                },
              ),
            ]),
            const SizedBox(height: 26),
            _heading(context, 'ARROW PUZZLE'),
            _SettingsCard(children: [
              ListTile(
                leading: const _SettingsIcon(icon: Icons.star_rounded),
                title: const Text('Rate us'),
                subtitle: const Text('Share your thoughts on Google Play'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => _openLink(context, AppLinks.playStore),
              ),
              const Divider(height: 1, indent: 72, endIndent: 16),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.shield_outlined),
                title: const Text('Privacy policy'),
                subtitle: const Text('Read on NishArc Studios'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => _openLink(context, AppLinks.privacyPolicy),
              ),
            ]),
            const SizedBox(height: 20),
            _SettingsCard(children: [
              ListTile(
                leading: _SettingsIcon(
                    icon: Icons.restart_alt_rounded, color: colors.error),
                title: Text('Reset progress',
                    style: TextStyle(color: colors.error)),
                subtitle: const Text('Start again from level 1'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _resetProgress(context, ref),
              ),
            ]),
            const SizedBox(height: 24),
            Text('NishArc Studios',
                textAlign: TextAlign.center,
                style:
                    text.labelMedium?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 10),
        child: Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                )),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: tint.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: tint, size: 22),
    );
  }
}
