import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/level.dart';
import '../game/game_controller.dart';
import 'palette.dart';
import 'vehicle_painter.dart';

/// Passengers walking a winding queue towards the boarding gate at the
/// bottom-left. The front of the queue is nearest the bays; everyone behind
/// is visible along the snake path and shuffles forward as people board.
class QueueView extends StatefulWidget {
  final GameController controller;
  const QueueView({super.key, required this.controller});

  static const rows = 3;
  static const rowHeight = 38.0;
  static const size = 28.0;

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final level = controller.level;
    final front = controller.state.front;
    final left = level.queue.length - front;
    const rows = QueueView.rows, rowH = QueueView.rowHeight;
    const size = QueueView.size;
    return Container(
      height: rows * rowH + 16,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFE6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.cardBorder),
        boxShadow: Palette.softShadow(0.6),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          const gate = 34.0, badge = 52.0;
          final trackW = box.maxWidth - gate - badge;
          final perRow = max(2, (trackW / (size * 0.82)).floor());
          final step = trackW / perRow;
          final visible = min(left, perRow * rows);

          // Index along the snake -> position. Row 0 is the bottom row and
          // runs left to right from the gate; rows alternate direction.
          Offset at(int k) {
            final r = k ~/ perRow, c = k % perRow;
            final col = r.isEven ? c : perRow - 1 - c;
            return Offset(
              gate + col * step + (step - size) / 2,
              (rows - 1 - r) * rowH + (rowH - size - 6) / 2,
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: gate,
                top: 0,
                width: trackW,
                height: rows * rowH,
                child: CustomPaint(
                  painter: _SnakePainter(rows: rows, rowHeight: rowH),
                ),
              ),
              // Boarding gate.
              Positioned(
                left: 0,
                bottom: 2,
                width: gate - 4,
                height: rowH - 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Palette.blue,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: Palette.softShadow(0.4),
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _walk,
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var k = visible - 1; k >= 0; k--)
                      AnimatedPositioned(
                        key: ValueKey('pax-${front + k}'),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOut,
                        left: at(k).dx,
                        top: at(k).dy,
                        width: size,
                        height: size + 6,
                        child: CustomPaint(
                          painter: PassengerPainter(
                            Palette.vehicle(level.queue[front + k]),
                            // Everyone shuffles on the spot; the front few
                            // step a little faster.
                            step: (_walk.value + k * 0.13) % 1.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: badge - 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 18,
                      color: Palette.inkSoft,
                    ),
                    Text(
                      '$left',
                      key: const Key('pax-left'),
                      style: const TextStyle(
                        color: Palette.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The winding walkway with guide rails.
class _SnakePainter extends CustomPainter {
  final int rows;
  final double rowHeight;
  _SnakePainter({required this.rows, required this.rowHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final lane = rowHeight * 0.78;
    final path = Path();
    for (var r = 0; r < rows; r++) {
      final y = (rows - 1 - r) * rowHeight + rowHeight / 2;
      final fromLeft = r.isEven;
      final x0 = fromLeft ? 0.0 : size.width - lane / 2;
      final x1 = fromLeft ? size.width - lane / 2 : lane / 2;
      if (r == 0) path.moveTo(x0, y);
      path.lineTo(x1, y);
      if (r < rows - 1) {
        // U-turn up to the next row.
        path.arcToPoint(
          Offset(x1, y - rowHeight),
          radius: Radius.circular(rowHeight / 2),
          clockwise: !fromLeft,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lane + 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFD54F),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lane
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE2DCCD),
    );
    // Footprint dashes down the middle of the walkway.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.7);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, d + 6), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_SnakePainter old) =>
      old.rows != rows || old.rowHeight != rowHeight;
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
        const height = 150.0;
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
