import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/board_view.dart';
import '../widgets/palette.dart';
import '../widgets/screw_painter.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'splash_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user;
    // Briefly null while logging out, before this route is removed.
    if (user == null) {
      return const Scaffold(body: GameBackground(child: SizedBox.expand()));
    }
    final p = app.progress;
    final completed = p.stars.length;
    final total = app.levels.count;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      key: const Key('profile'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      child: Row(
                        children: [
                          Avatar(index: user.avatar),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                key: const Key('display-name'),
                                style: const TextStyle(
                                  color: Palette.ink,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Palette.accent,
                                    size: 16,
                                  ),
                                  Text(
                                    ' ${p.totalStars}',
                                    style: const TextStyle(
                                      color: Palette.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    CoinChip(coins: p.coins),
                    IconButton(
                      key: const Key('settings'),
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Palette.ink,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const _SpinningScrews(),
                const SizedBox(height: 18),
                const Logo(size: 46),
                const Spacer(),
                GameButton(
                  key: const Key('play'),
                  label: 'LEVEL ${app.currentLevel}',
                  icon: Icons.play_arrow_rounded,
                  height: 72,
                  color: Palette.green,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(number: app.currentLevel),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GameButton(
                  key: const Key('levels'),
                  label: 'ALL LEVELS',
                  icon: Icons.grid_view_rounded,
                  color: Palette.blue,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LevelSelectScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completed / total,
                    minHeight: 10,
                    backgroundColor: Colors.white,
                    color: Palette.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completed / $total levels completed',
                  style: const TextStyle(color: Palette.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinningScrews extends StatefulWidget {
  const _SpinningScrews();

  @override
  State<_SpinningScrews> createState() => _SpinningScrewsState();
}

class _SpinningScrewsState extends State<_SpinningScrews>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // A tiny diorama: plates on a pegboard held by slowly turning bolts.
  static const _cell = 52.0;
  static const _plates = [
    (0, 0, 3, 1, 1),
    (2, 0, 1, 3, 0),
    (0, 1, 2, 2, 2),
    (3, 1, 2, 2, 3),
  ];
  static const _bolts = [
    (0, 0, 0),
    (2, 0, 1),
    (2, 2, 3),
    (0, 2, 2),
    (1, 1, 4),
    (4, 1, 5),
    (3, 2, 6),
  ];

  @override
  Widget build(BuildContext context) {
    const w = _cell * 5, h = _cell * 3;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Palette.woodMid, Palette.woodDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: Palette.softShadow(1.3),
      ),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(painter: WoodBoardPainter(5, 3)),
              ),
            ),
            for (final (x, y, pw, ph, c) in _plates)
              Positioned(
                left: x * _cell,
                top: y * _cell,
                width: pw * _cell,
                height: ph * _cell,
                child: CustomPaint(
                  painter: PlatePainter(Palette.plate(c), const [], _cell),
                ),
              ),
            AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Stack(
                children: [
                  for (final (x, y, c) in _bolts)
                    Positioned(
                      left: (x + 0.15) * _cell,
                      top: (y + 0.15) * _cell,
                      child: ScrewIcon(
                        color: Palette.screw(c),
                        size: _cell * 0.7,
                        angle: _c.value * 6.283 * (c.isEven ? 1 : -1),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
