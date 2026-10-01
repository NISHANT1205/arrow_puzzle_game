import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/level.dart';
import '../game/game_controller.dart';
import 'palette.dart';
import 'vehicle_painter.dart';

/// Passengers waiting on the platform, front of the queue on the left.
class QueueView extends StatelessWidget {
  final GameController controller;
  const QueueView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final level = controller.level;
    final front = controller.state.front;
    return LayoutBuilder(
      builder: (context, box) {
        const size = 30.0, gap = 2.0;
        const step = size + gap;
        final visible = max(1, ((box.maxWidth - 90) / step).floor());
        final left = level.queue.length - front;
        return Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Palette.cardBorder),
            boxShadow: Palette.softShadow(0.6),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Palette.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Platform edge.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 4,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE082),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    for (var k = 0; k < min(visible, left); k++)
                      AnimatedPositioned(
                        key: ValueKey('pax-${front + k}'),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                        left: k * step,
                        top: 6,
                        width: size,
                        height: size + 6,
                        child: CustomPaint(
                          painter: PassengerPainter(
                            Palette.vehicle(level.queue[front + k]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Palette.field,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 16,
                      color: Palette.inkSoft,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$left',
                      key: const Key('pax-left'),
                      style: const TextStyle(
                        color: Palette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Station bays where vehicles wait for passengers.
class BaysView extends StatelessWidget {
  final GameController controller;
  final VoidCallback onAddBay;
  const BaysView({super.key, required this.controller, required this.onAddBay});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final level = controller.level;
    final locked = controller.canAddBay ? 1 : 0;
    final count = state.bays.length + locked;
    final full = !state.hasFreeBay;
    return LayoutBuilder(
      builder: (context, box) {
        // 10px padding and 3px border on each side.
        final bw = (box.maxWidth - 26) / count;
        const height = 172.0;
        // Inner height minus padding (14), border (6) and the seat badge (22)
        // must fit the longest vehicle, a 4-cell bus drawn 1.08 x per cell.
        final vw = min(bw * 0.6, (height - 14 - 6 - 22) / (4 * 1.08));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: height,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.asphaltLight, Palette.asphalt],
            ),
            border: Border.all(
              color: full ? const Color(0xFFE53935) : Palette.curb,
              width: 3,
            ),
            boxShadow: Palette.softShadow(0.7),
          ),
          child: Row(
            // Stretch so every bay (and its markings) is full height.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < state.bays.length; i++)
                SizedBox(width: bw, child: _bay(i, vw, level)),
              if (locked == 1)
                SizedBox(
                  width: bw,
                  child: Center(
                    child: GestureDetector(
                      key: const Key('add-bay'),
                      onTap: onAddBay,
                      child: Container(
                        width: min(bw - 8, 44),
                        height: 44,
                        decoration: BoxDecoration(
                          color: Palette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: Palette.softShadow(0.4),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bay(int i, double vw, LevelDef level) {
    final state = controller.state;
    final bay = state.bays[i];
    final ghost = controller.departed.where((d) => d.$1 == i).toList();
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Bay markings.
        Positioned.fill(
          child: CustomPaint(painter: _BayLinesPainter(first: i == 0)),
        ),
        if (bay != null)
          _parked(
            bay.vehicle,
            bay.filled,
            vw,
            level,
            arriving: controller.exiting == bay.vehicle,
          ),
        for (final (_, v) in ghost) _leaving(v, vw, level),
      ],
    );
  }

  Widget _vehicleBox(int v, double vw, LevelDef level, {int? boarded}) {
    final def = level.vehicles[v];
    return SizedBox(
      width: vw,
      height: vw * def.length * 1.08,
      child: CustomPaint(
        painter: VehiclePainter(
          Palette.vehicle(def.color),
          def.kind,
          arrow: false,
          boarded: boarded,
        ),
      ),
    );
  }

  Widget _parked(
    int v,
    int filled,
    double vw,
    LevelDef level, {
    required bool arriving,
  }) {
    final def = level.vehicles[v];
    Widget car = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _vehicleBox(v, vw, level, boarded: filled),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$filled/${def.seats}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Palette.ink,
            ),
          ),
        ),
      ],
    );
    if (arriving) {
      car = TweenAnimationBuilder<double>(
        key: ValueKey('arrive-$v-${controller.stamp}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, t, child) => Transform.translate(
          offset: Offset(0, (1 - t) * 60),
          child: Opacity(opacity: t.clamp(0, 1), child: child),
        ),
        child: car,
      );
    }
    return car;
  }

  Widget _leaving(int v, double vw, LevelDef level) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('depart-$v-${controller.stamp}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeIn,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, -t * 140),
        child: Opacity(opacity: (1 - t).clamp(0, 1), child: child),
      ),
      child: IgnorePointer(
        child: _vehicleBox(v, vw, level, boarded: level.vehicles[v].seats),
      ),
    );
  }
}

class _BayLinesPainter extends CustomPainter {
  final bool first;
  _BayLinesPainter({required this.first});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.5;
    if (first) canvas.drawLine(Offset(0, 4), Offset(0, size.height - 18), p);
    canvas.drawLine(
      Offset(size.width, 4),
      Offset(size.width, size.height - 18),
      p,
    );
  }

  @override
  bool shouldRepaint(_BayLinesPainter old) => old.first != first;
}
