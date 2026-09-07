// lib/screens/level_select_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level.dart';
import '../state/level_provider.dart';
import '../state/progress_provider.dart';
import 'game_screen.dart';

class LevelSelectScreen extends ConsumerWidget {
  final String packName;

  const LevelSelectScreen({Key? key, required this.packName}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(levelsByPackProvider(packName));

    return Scaffold(
      appBar: AppBar(
        title: Text('$packName Pack'),
        centerTitle: true,
      ),
      body: levelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (levels) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: levels.length,
            itemBuilder: (context, index) {
              final level = levels[index];
              return _LevelTile(level: level);
            },
          );
        },
      ),
    );
  }
}

class _LevelTile extends ConsumerWidget {
  final Level level;

  const _LevelTile({required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(levelProgressProvider(level.id));
    final isCompleted = progress.isCompleted;
    final stars = progress.stars;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameScreen(level: level),
          ),
        );
      },
      child: Card(
        elevation: isCompleted ? 4 : 2,
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isCompleted
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      level.id.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${level.gridSize}×${level.gridSize}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            // Completion indicator
            if (isCompleted)
              Positioned(
                top: 4,
                right: 4,
                child: Column(
                  children: [
                    for (int i = 0; i < 3; i++)
                      Icon(
                        Icons.star,
                        size: 12,
                        color: i < stars
                            ? Colors.amber
                            : Colors.grey.withOpacity(0.3),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
