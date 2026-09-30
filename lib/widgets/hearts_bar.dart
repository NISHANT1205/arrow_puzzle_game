// lib/widgets/hearts_bar.dart

import 'package:flutter/material.dart';

/// Row of lives. A heart that is lost pops and fades to grey.
class HeartsBar extends StatelessWidget {
  const HeartsBar({super.key, required this.lives, required this.maxLives});

  final int lives;
  final int maxLives;

  static const _red = Color(0xFFF03E5A);

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.onSurface.withValues(alpha: .18);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < maxLives; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: i < lives ? 1 : 0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (_, v, __) => Transform.scale(
                scale: .8 + .2 * v.clamp(0.0, 1.2),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 30,
                  color: Color.lerp(empty, _red, v.clamp(0.0, 1.0)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
