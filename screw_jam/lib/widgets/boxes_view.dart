import 'package:flutter/material.dart';

import '../engine/level.dart';
import '../game/game_controller.dart';
import 'palette.dart';
import 'screw_painter.dart';

/// The open colour boxes waiting for screws.
class BoxesView extends StatelessWidget {
  final GameController controller;
  const BoxesView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final left = controller.level.boxes.length - state.nextBox;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < state.active.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _slide(
              i,
              _box(state.active[i]?.color, state.active[i]?.count ?? 0),
            ),
          ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                color: Colors.white70,
                size: 18,
              ),
              Text(
                '+$left',
                key: const Key('boxes-left'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slide(int slot, Widget child) {
    if (!controller.completedSlots.contains(slot)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('box-$slot-${controller.stamp}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Transform.translate(
        offset: Offset(0, (1 - t) * -60),
        child: Opacity(opacity: t.clamp(0, 1), child: c),
      ),
      child: child,
    );
  }

  Widget _box(int? color, int count) {
    const size = 30.0;
    if (color == null) {
      return Container(
        width: 3 * size + 28,
        height: size + 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white38),
      );
    }
    final c = Palette.screw(color);
    return Container(
      width: 3 * size + 28,
      height: size + 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(c, Colors.white, 0.3)!, c],
        ),
        border: Border.all(color: Color.lerp(c, Colors.black, 0.35)!, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var k = 0; k < LevelDef.boxCapacity; k++)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.25),
              ),
              child: k < count
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.3, end: 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      builder: (_, s, ch) =>
                          Transform.scale(scale: s, child: ch),
                      child: ScrewIcon(color: c, size: size),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// The holding tray for screws that have no open box yet.
class TrayView extends StatelessWidget {
  final GameController controller;
  final VoidCallback onAddSlot;
  const TrayView({
    super.key,
    required this.controller,
    required this.onAddSlot,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final cap = state.bufferCapacity;
    final danger = state.buffer.length >= cap - 1;
    return LayoutBuilder(
      builder: (context, box) {
        final slots = cap + (controller.canAddSlot ? 1 : 0);
        final size = ((box.maxWidth - 32) / slots - 8).clamp(20.0, 38.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger ? Colors.redAccent : Colors.white24,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = 0; k < cap; k++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: k < state.buffer.length
                      ? ScrewIcon(
                          color: Palette.screw(
                            controller.level.screws[state.buffer[k]].color,
                          ),
                          size: size,
                        )
                      : null,
                ),
              if (controller.canAddSlot)
                GestureDetector(
                  onTap: onAddSlot,
                  child: Container(
                    key: const Key('add-slot'),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.accent.withValues(alpha: 0.2),
                      border: Border.all(color: Palette.accent),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Palette.accent,
                      size: size * 0.6,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
