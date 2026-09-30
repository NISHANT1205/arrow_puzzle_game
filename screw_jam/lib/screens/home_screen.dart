import 'package:flutter/material.dart';

import '../widgets/common.dart';
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
                                  color: Colors.white,
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
                                      color: Colors.white70,
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
                        color: Colors.white,
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
                  color: const Color(0xFF43A047),
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
                  color: const Color(0xFF1E88E5),
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
                    backgroundColor: Colors.white12,
                    color: Palette.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completed / $total levels completed',
                  style: const TextStyle(color: Colors.white70),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.translate(
                offset: Offset(
                  0,
                  8 *
                      (i.isEven ? 1 : -1) *
                      (0.5 - (_c.value * 2 % 1 - 0.5).abs()),
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CustomPaint(
                    painter: ScrewPainter(
                      Palette.screw(i),
                      angle: _c.value * 6.283 * (i.isEven ? 1 : -1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
