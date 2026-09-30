// lib/screens/level_select_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/level_generator.dart';
import '../state/progress_provider.dart';
import '../widgets/tier_badge.dart';

/// Grid of levels. Cleared and current levels are playable; the next few
/// locked levels are shown greyed out.
class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key, required this.onPlay});

  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(progressProvider).currentLevel;
    final shown = ((current + 30) ~/ 10 + 1) * 10;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Levels')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 76,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: shown,
        itemBuilder: (context, i) {
          final level = i + 1;
          final cleared = level < current;
          final isCurrent = level == current;
          final locked = level > current;
          final bg = isCurrent
              ? const Color(0xFF2E90FF)
              : cleared
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: .5);
          final fg = isCurrent
              ? Colors.white
              : cleared
                  ? scheme.onPrimaryContainer
                  : scheme.onSurface.withValues(alpha: .35);
          return Material(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: locked
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onPlay(level);
                    },
              child: Stack(
                children: [
                  if (LevelGenerator.tierFor(level) != LevelTier.normal)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color:
                            TierBadge.colorFor(LevelGenerator.tierFor(level)),
                      ),
                    ),
                  Center(
                    child: locked
                        ? Icon(Icons.lock_rounded, color: fg, size: 20)
                        : Text(
                            '$level',
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
