// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/level_generator.dart';
import '../state/game_controller.dart';
import '../state/progress_provider.dart';
import '../widgets/arrow_board_view.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // A small real puzzle used as the logo.
  final GameController _preview = GameController(LevelGenerator.generate(6));

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  void _play(int level) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filledTonal(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ),
            ),
            const Spacer(),
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final level = _preview.level;
                  final cell = (constraints.maxWidth * .55) / level.cols;
                  return ArrowBoardView(
                    controller: _preview,
                    cellSize: cell.clamp(10.0, 34.0),
                    palette: dark ? BoardPalette.dark : BoardPalette.light,
                  );
                },
              ),
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
                    backgroundColor: const Color(0xFF2E90FF),
                    foregroundColor: Colors.white,
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LevelSelectScreen(onPlay: _play),
                ),
              ),
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
