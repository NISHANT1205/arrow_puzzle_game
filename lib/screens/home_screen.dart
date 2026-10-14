// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progress_provider.dart';
import '../services/audio_service.dart';
import '../services/player_profile_service.dart';
import '../widgets/player_avatar.dart';
import 'profile_screen.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final service = PlayerProfileService.instance;
    await service.loadCachedProfile();
    try {
      await service.ensureProfile();
    } catch (_) {
      // The saved profile stays visible when offline.
    }
  }

  void _play(int level) {
    AudioService().playUITap();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: ValueListenableBuilder<PlayerProfile?>(
                    valueListenable: PlayerProfileService.instance.profile,
                    builder: (context, player, _) => Semantics(
                      button: true,
                      label: 'Edit player profile',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          AudioService().playUITap();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const ProfileScreen()));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(children: [
                            PlayerAvatar(
                                avatarId: player?.avatarId ?? 0, size: 48),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(player?.username ?? 'Player',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                Text('View profile',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                              ],
                            )),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () {
                    AudioService().playUITap();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ]),
            ),
            const Spacer(),
            LayoutBuilder(
              builder: (context, constraints) {
                final size = (constraints.maxWidth * .48).clamp(120.0, 200.0);
                return Semantics(
                  label: 'Arrow Puzzle logo',
                  image: true,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size * .22),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: .14),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(size * .22),
                      child: Image.asset(
                        'assets/icon/app_icon_ios.png',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Arrow Puzzle',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap an arrow to slide it out.\nDon\'t let it crash!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: .6),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _play(progress.currentLevel),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text('Level ${progress.currentLevel}'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                AudioService().playUITap();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LevelSelectScreen(onPlay: _play),
                  ),
                );
              },
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('All levels'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
