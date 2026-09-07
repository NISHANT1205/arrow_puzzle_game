import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/level.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../state/game_provider.dart';
import 'arrow_tile.dart';
import 'maze_arrow.dart';

class ArrowBoardWidget extends ConsumerStatefulWidget {
  final Level level;
  final VoidCallback? onGameWon;

  const ArrowBoardWidget({super.key, required this.level, this.onGameWon});

  @override
  ConsumerState<ArrowBoardWidget> createState() => _ArrowBoardWidgetState();
}

class _ArrowBoardWidgetState extends ConsumerState<ArrowBoardWidget> {
  final _audio = AudioService();
  final _haptics = HapticService();
  (Arrow, double)? _flying;
  final Map<(int, int), int> _shakeIds = {};

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    if (game == null) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final available = math.min(constraints.maxWidth, constraints.maxHeight);
      final boardSize = math.max(0.0, available - 12);
      const spacing = .5;
      final tileSize = (boardSize - spacing * (widget.level.gridSize - 1)) /
          widget.level.gridSize;
      final pitch = tileSize + spacing;

      return Center(
        child: SizedBox.square(
          dimension: boardSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.level.gridSize,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                ),
                itemCount: widget.level.gridSize * widget.level.gridSize,
                itemBuilder: (_, index) {
                  final row = index ~/ widget.level.gridSize;
                  final col = index % widget.level.gridSize;
                  final arrow = game.board.getArrowAt(row, col);
                  if (arrow == null) return const SizedBox.shrink();
                  final position = (row, col);
                  final shakeId = _shakeIds[position] ?? 0;
                  return KeyedSubtree(
                    key: ValueKey('$row-$col-$shakeId'),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: shakeId == 0
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      builder: (_, value, child) => Transform.translate(
                        offset: Offset(
                          shakeId == 0
                              ? 0
                              : math.sin(value * math.pi * 6) * 7 * (1 - value),
                          0,
                        ),
                        child: child,
                      ),
                      child: ArrowTile(
                        arrow: arrow,
                        size: tileSize,
                        isHinted: game.hintedArrow?.row == row &&
                            game.hintedArrow?.col == col,
                        onTap: _flying == null
                            ? () => _tap(arrow, tileSize)
                            : () {},
                      ),
                    ),
                  );
                },
              ),
              if (_flying case (final arrow, final size))
                Positioned(
                  left: arrow.col * pitch,
                  top: arrow.row * pitch,
                  width: size,
                  height: size,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MazeArrowMetrics.moveDuration,
                    curve: Curves.easeInOut,
                    onEnd: _finishFlight,
                    builder: (_, value, __) {
                      final axis = arrowAxis(arrow.direction);
                      final distance = (boardSize + size) * value;

                      // Head leads, tail stretches out behind it mid-flight.
                      final stretch = math.sin(value * math.pi) * .18;
                      const centre = Offset(0.5, 0.5);
                      final head = centre +
                          axis * (MazeArrowMetrics.arrowLengthRatio / 2);
                      final tail = centre -
                          axis *
                              (MazeArrowMetrics.arrowLengthRatio / 2 + stretch);

                      return Opacity(
                        opacity: 1 - value,
                        child: Transform.translate(
                          offset: Offset(
                            axis.dx * distance,
                            axis.dy * distance,
                          ),
                          child: MazeArrow(
                            points: [tail, head],
                            cellSize: size,
                            animateColor: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _tap(Arrow arrow, double tileSize) async {
    final success =
        ref.read(gameProvider.notifier).tapArrow(arrow.row, arrow.col);
    if (!success) {
      final position = (arrow.row, arrow.col);
      setState(() => _shakeIds[position] = (_shakeIds[position] ?? 0) + 1);
      await Future.wait([_audio.playBlockedTap(), _haptics.blockedMove()]);
      return;
    }
    setState(() => _flying = (arrow, tileSize));
    await Future.wait([_audio.playSlideOff(), _haptics.successMove()]);
  }

  Future<void> _finishFlight() async {
    if (!mounted) return;
    setState(() => _flying = null);
    if (ref.read(gameProvider)?.isWon ?? false) {
      await Future.wait([_audio.playLevelComplete(), _haptics.levelComplete()]);
      if (mounted) widget.onGameWon?.call();
    }
  }
}
