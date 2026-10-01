import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/palette.dart';
import '../engine/level.dart';
import '../widgets/vehicle_painter.dart';
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
                const _StreetScene(),
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

class _StreetScene extends StatefulWidget {
  const _StreetScene();

  @override
  State<_StreetScene> createState() => _StreetSceneState();
}

class _StreetSceneState extends State<_StreetScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // A little street: a bus and cars drive by in a loop; passengers wait.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = min(box.maxWidth, 360.0);
        const h = 170.0;
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Palette.grass,
            boxShadow: Palette.softShadow(1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final t = _c.value;
              return Stack(
                children: [
                  // Road with dashed centre line.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 62,
                    height: 70,
                    child: CustomPaint(painter: _RoadPainter()),
                  ),
                  // Pavement with waiting passengers.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 20,
                    height: 42,
                    child: Container(color: Palette.curb),
                  ),
                  for (var i = 0; i < 7; i++)
                    Positioned(
                      left: 18.0 + i * 30,
                      top:
                          18 +
                          (i.isEven ? 0 : 2) -
                          3 * sin((t * 8 + i) * pi).abs(),
                      width: 26,
                      height: 34,
                      child: CustomPaint(
                        painter: PassengerPainter(Palette.vehicle(i)),
                      ),
                    ),
                  _drive(t, 0.0, w, 66, VehicleKind.bus, 1, 120),
                  _drive(t, 0.45, w, 66, VehicleKind.car, 0, 62),
                  _drive(t, 0.7, w, 100, VehicleKind.van, 3, 90, reverse: true),
                  _drive(t, 0.2, w, 100, VehicleKind.car, 7, 62, reverse: true),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _drive(
    double t,
    double phase,
    double w,
    double top,
    VehicleKind kind,
    int color,
    double len, {
    bool reverse = false,
  }) {
    final p = (t + phase) % 1.0;
    final x = reverse
        ? w - p * (w + len * 2) + len
        : p * (w + len * 2) - len * 2;
    return Positioned(
      left: x,
      top: top,
      width: len,
      height: 28,
      child: RotatedBox(
        quarterTurns: reverse ? 3 : 1,
        child: CustomPaint(
          painter: VehiclePainter(Palette.vehicle(color), kind, arrow: false),
        ),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.road);
    final dash = Paint()
      ..color = const Color(0xFFFFE082)
      ..strokeWidth = 3;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 14, size.height / 2),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => false;
}
