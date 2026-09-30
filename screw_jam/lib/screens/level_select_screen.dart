import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/palette.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static const _perRow = 5;
  ScrollController? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scroll == null) {
      final row = (AppScope.read(context).currentLevel - 1) ~/ _perRow;
      _scroll = ScrollController(
        initialScrollOffset: (row - 2).clamp(0, 1 << 20) * 72.0,
      );
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.progress;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Levels',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          CoinChip(coins: p.coins),
          const SizedBox(width: 12),
        ],
      ),
      body: GameBackground(
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _perRow,
            mainAxisExtent: 64,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: app.levels.count,
          itemBuilder: (context, i) {
            final n = i + 1;
            final unlocked = n <= p.unlocked;
            final stars = p.stars[n] ?? 0;
            final boss = n % 10 == 0;
            final color = !unlocked
                ? const Color(0xFFE2DEEC)
                : boss
                ? const Color(0xFFD81B60)
                : (stars > 0 ? Palette.green : Palette.blue);
            return GestureDetector(
              key: Key('level-$n'),
              onTap: unlocked
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GameScreen(number: n)),
                    )
                  : () => showToast(
                      context,
                      'Beat level ${p.unlocked} to unlock',
                    ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  border: n == p.unlocked
                      ? Border.all(color: Palette.accent, width: 3)
                      : Border(
                          bottom: BorderSide(
                            color: Colors.black.withValues(alpha: 0.3),
                            width: 4,
                          ),
                        ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    unlocked
                        ? Text(
                            '$n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : const Icon(
                            Icons.lock_rounded,
                            color: Palette.inkSoft,
                            size: 20,
                          ),
                    if (unlocked)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var s = 0; s < 3; s++)
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: s < stars
                                  ? Palette.accent
                                  : Colors.black26,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
