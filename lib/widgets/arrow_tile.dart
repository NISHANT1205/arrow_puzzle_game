// lib/widgets/arrow_tile.dart
//
// Board-facing arrow widgets. Public API is unchanged: these widgets take the
// same constructor arguments as before, so no game logic, level data or input
// handling had to move. Everything below is presentation only — the actual
// drawing lives in maze_arrow.dart.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/level.dart';
import 'maze_arrow.dart';

/// Screen-space unit vector for a board direction (x = column, y = row).
Offset arrowAxis(ArrowDirection direction) {
  final (rowDelta, colDelta) = direction.getDelta();
  final raw = Offset(colDelta.toDouble(), rowDelta.toDouble());
  return raw / raw.distance;
}

class ArrowTile extends StatefulWidget {
  final Arrow arrow;
  final double size;
  final bool isHinted;
  final VoidCallback onTap;
  final Duration? slideOutDuration;
  final VoidCallback? onSlideOutComplete;

  const ArrowTile({
    super.key,
    required this.arrow,
    required this.size,
    required this.onTap,
    this.isHinted = false,
    this.slideOutDuration,
    this.onSlideOutComplete,
  });

  @override
  State<ArrowTile> createState() => _ArrowTileState();
}

class _ArrowTileState extends State<ArrowTile> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.isHinted;
    final radius = widget.size * MazeArrowMetrics.highlightRadiusRatio;
    final visualSeed = widget.arrow.row * 37 +
        widget.arrow.col * 23 +
        widget.arrow.direction.index * 11;
    final sizeVariant = visualSeed % 49;
    // Let neighbouring maze paths visually weave into one compact composition.
    // The widget's hit box remains exactly one logical grid cell.
    final visualScale = .82 + sizeVariant / 100;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed || _hovered || highlighted
              ? MazeArrowMetrics.pressScale
              : 1,
          duration: MazeArrowMetrics.pressDuration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: MazeArrowMetrics.colorDuration,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: highlighted
                  ? ArrowPalette.blue.withValues(alpha: .10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: highlighted
                    ? ArrowPalette.blue.withValues(alpha: .24)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Transform.scale(
              scale: visualScale,
              child: MazeArrow.single(
                direction: arrowAxis(widget.arrow.direction),
                cellSize: widget.size,
                variant: visualSeed,
                state: highlighted
                    ? ArrowVisualState.active
                    : ArrowVisualState.idle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated arrow tile that slides off the board.
///
/// The body translates along its own axis with the head leading: the tail
/// stretches out behind the head at the start of the move and catches up at
/// the end.
class SlidingArrowTile extends StatefulWidget {
  final Arrow arrow;
  final double size;
  final (int, int, int) destination; // (endRow, endCol, cellsTraversed)
  final Duration duration;
  final VoidCallback onComplete;

  const SlidingArrowTile({
    super.key,
    required this.arrow,
    required this.size,
    required this.destination,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<SlidingArrowTile> createState() => _SlidingArrowTileState();
}

class _SlidingArrowTileState extends State<SlidingArrowTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    vsync: this,
  );

  late final Animation<double> _move = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (_, _, cellsTraversed) = widget.destination;
    final axis = arrowAxis(widget.arrow.direction);

    return AnimatedBuilder(
      animation: _move,
      builder: (context, _) {
        final t = _move.value;
        final travelled = t * cellsTraversed * widget.size;

        // The tail lags behind the head mid-flight, then snaps back in line.
        final stretch = math.sin(t * math.pi) * .18;
        const centre = Offset(0.5, 0.5);
        final head = centre + axis * (MazeArrowMetrics.arrowLengthRatio / 2);
        final tail =
            centre - axis * (MazeArrowMetrics.arrowLengthRatio / 2 + stretch);

        return Transform.translate(
          offset: Offset(axis.dx * travelled, axis.dy * travelled),
          child: Opacity(
            opacity: 1 - Curves.easeInQuad.transform(t),
            child: SizedBox.square(
              dimension: widget.size,
              child: MazeArrow(
                points: [tail, head],
                cellSize: widget.size,
                animateColor: false,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bouncing arrow tile for blocked taps.
class BouncingArrowTile extends StatefulWidget {
  final Arrow arrow;
  final double size;

  const BouncingArrowTile({
    super.key,
    required this.arrow,
    required this.size,
  });

  @override
  State<BouncingArrowTile> createState() => _BouncingArrowTileState();
}

class _BouncingArrowTileState extends State<BouncingArrowTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  )..forward();

  late final Animation<double> _shake = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final shake = (1 - (2 * (_shake.value - 0.5).abs())) * 4;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: ArrowTile(
        arrow: widget.arrow,
        size: widget.size,
        onTap: () {},
      ),
    );
  }
}
