// lib/widgets/tier_badge.dart

import 'package:flutter/material.dart';

import '../engine/level_generator.dart';

/// "HARD" / "SUPER HARD" pill shown under the level title.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier});

  final LevelTier tier;

  static Color colorFor(LevelTier tier) => switch (tier) {
        LevelTier.normal => const Color(0xFF2E90FF),
        LevelTier.hard => const Color(0xFFFF8A1F),
        LevelTier.superHard => const Color(0xFFE5304F),
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(tier);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            tier.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}
