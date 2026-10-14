// lib/screens/level_select_screen.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/level_generator.dart';
import '../services/level_repository.dart';
import '../state/progress_provider.dart';
import '../services/audio_service.dart';

/// Cleared and current levels are playable; later levels stay locked.
class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key, required this.onPlay});

  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(progressProvider).currentLevel;
    final total = LevelRepository.instance.bundledCount;
    final shown = math.min(total, ((current + 30) ~/ 10 + 1) * 10);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Levels'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              AudioService().playUITap();
              Navigator.of(context).pop();
            },
          )),
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
              ? scheme.primary
              : cleared
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: .5);
          final fg = isCurrent
              ? scheme.onPrimary
              : cleared
                  ? scheme.onPrimaryContainer
                  : scheme.onSurface.withValues(alpha: locked ? .35 : 1);
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
                  if (LevelRepository.instance.isCube(level))
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Icon(
                        Icons.view_in_ar_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ),
                  if (LevelTier.forLevel(level) != LevelTier.normal)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: scheme.primary,
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
