import 'package:flutter/material.dart';

import '../engine/level.dart';
import '../game/game_controller.dart';
import 'board_view.dart';
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
              _Box(
                color: state.active[i]?.color,
                count: state.active[i]?.count ?? 0,
              ),
            ),
          ),
        const SizedBox(width: 4),
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.cardBorder),
            boxShadow: Palette.softShadow(0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                color: Palette.inkSoft,
                size: 20,
              ),
              Text(
                '+$left',
                key: const Key('boxes-left'),
                style: const TextStyle(
                  color: Palette.ink,
                  fontWeight: FontWeight.w800,
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
}

/// A small plastic parts box with a lid strip and three bolt sockets.
class _Box extends StatelessWidget {
  final int? color;
  final int count;
  const _Box({required this.color, required this.count});

  static const _socket = 30.0;
  static const _width = 3 * _socket + 34;
  static const _height = _socket + 36;

  @override
  Widget build(BuildContext context) {
    if (color == null) {
      return Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.cardBorder, width: 2),
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          color: Palette.green,
          size: 28,
        ),
      );
    }
    final c = Palette.screw(color!);
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: PlatePainter(c, const [], 44, seed: 100 + color!),
            ),
          ),
          Column(
            children: [
              // Carved finger slot for lifting the crate.
              Container(
                width: 30,
                height: 6,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: Palette.shade(c, -0.35).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var k = 0; k < LevelDef.boxCapacity; k++)
                      SizedBox(
                        width: _socket,
                        height: _socket,
                        child: CustomPaint(
                          painter: WoodHolePainter(c),
                          child: k < count
                              ? TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.3, end: 1),
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutBack,
                                  builder: (_, s, ch) =>
                                      Transform.scale(scale: s, child: ch),
                                  child: ScrewIcon(
                                    color: c,
                                    size: _socket,
                                    angle: k * 0.4,
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The wooden holding tray for screws that have no open box yet.
class TrayView extends StatelessWidget {
  final GameController controller;
  final VoidCallback onAddSlot;
  const TrayView({
    super.key,
    required this.controller,
    required this.onAddSlot,
  });

  static const _trayWood = Color(0xFFC89B62);

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final cap = state.bufferCapacity;
    final danger = state.buffer.length >= cap - 1;
    return LayoutBuilder(
      builder: (context, box) {
        final slots = cap + (controller.canAddSlot ? 1 : 0);
        final size = ((box.maxWidth - 32) / slots - 8).clamp(20.0, 38.0);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: Palette.softShadow(0.7),
          ),
          foregroundDecoration: danger
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE53935),
                    width: 2.5,
                  ),
                )
              : null,
          child: CustomPaint(
            painter: PlatePainter(_trayWood, const [], 60, seed: 42),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var k = 0; k < cap; k++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(
                          painter: WoodHolePainter(_trayWood),
                          child: k < state.buffer.length
                              ? ScrewIcon(
                                  color: Palette.screw(
                                    controller
                                        .level
                                        .screws[state.buffer[k]]
                                        .color,
                                  ),
                                  size: size,
                                  angle: k * 0.5,
                                )
                              : null,
                        ),
                      ),
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
                          color: Palette.accent,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: Palette.softShadow(0.4),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: size * 0.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
