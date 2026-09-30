import 'package:flutter/material.dart';

import '../engine/game_state.dart';
import '../game/game_controller.dart';
import '../widgets/board_view.dart';
import '../widgets/boxes_view.dart';
import '../widgets/common.dart';
import '../widgets/palette.dart';

class GameScreen extends StatefulWidget {
  final int number;
  const GameScreen({super.key, required this.number});

  static const hintCost = 30;
  static const slotCost = 60;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _ctrl;
  bool _ended = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      final app = AppScope.read(context);
      _ctrl = GameController(app.levels[widget.number]);
      app.recordPlay();
    }
  }

  bool _initialised = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap(int screw) {
    if (_ended) return;
    final app = AppScope.read(context);
    final r = _ctrl.tap(screw);
    switch (r) {
      case TapResult.toBox:
      case TapResult.toBuffer:
        app.click();
        app.buzz(heavy: _ctrl.fallenPlates.isNotEmpty);
        break;
      case TapResult.blocked:
        app.buzz();
        showToast(context, 'That screw is covered by another plate');
        break;
      case TapResult.trayFull:
        app.buzz(heavy: true);
        showToast(context, 'The tray is full!');
        break;
      case TapResult.invalid:
        break;
    }
    _checkEnd();
  }

  void _checkEnd() {
    if (_ended) return;
    if (_ctrl.isWon) {
      _ended = true;
      Future.delayed(const Duration(milliseconds: 650), _showWin);
    } else if (_ctrl.isStuck) {
      _ended = true;
      Future.delayed(const Duration(milliseconds: 400), _showFail);
    }
  }

  Future<void> _showWin() async {
    if (!mounted) return;
    final app = AppScope.read(context);
    final stars = _ctrl.stars;
    final earned = await app.recordWin(widget.number, stars);
    if (!mounted) return;
    final isLast = widget.number >= app.levels.count;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultDialog(
        title: isLast ? 'ALL LEVELS DONE!' : 'LEVEL COMPLETE!',
        stars: stars,
        subtitle: '+$earned coins',
        actions: [
          if (!isLast)
            GameButton(
              key: const Key('next-level'),
              label: 'NEXT',
              icon: Icons.arrow_forward_rounded,
              color: const Color(0xFF43A047),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(number: widget.number + 1),
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          GameButton(
            label: 'MENU',
            icon: Icons.home_rounded,
            color: const Color(0xFF1E88E5),
            height: 48,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showFail() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final app = AppScope.of(ctx);
        return _ResultDialog(
          title: 'OUT OF SPACE!',
          subtitle: 'No screw can move. Free up the tray to keep going.',
          actions: [
            if (_ctrl.canAddSlot)
              GameButton(
                key: const Key('fail-slot'),
                label: '+1 SLOT  (${GameScreen.slotCost})',
                icon: Icons.add_circle,
                onPressed: app.progress.coins >= GameScreen.slotCost
                    ? () {
                        Navigator.pop(ctx);
                        _addSlot();
                      }
                    : null,
              ),
            const SizedBox(height: 10),
            GameButton(
              key: const Key('fail-undo'),
              label: 'UNDO',
              icon: Icons.undo_rounded,
              color: const Color(0xFF8E24AA),
              height: 48,
              onPressed: () {
                Navigator.pop(ctx);
                _undo();
              },
            ),
            const SizedBox(height: 10),
            GameButton(
              key: const Key('fail-retry'),
              label: 'RETRY',
              icon: Icons.refresh_rounded,
              color: const Color(0xFF1E88E5),
              height: 48,
              onPressed: () {
                Navigator.pop(ctx);
                _restart();
              },
            ),
          ],
        );
      },
    );
  }

  void _undo() {
    if (!_ctrl.canUndo) return;
    _ctrl.undo();
    _ended = false;
  }

  void _restart() {
    _ctrl.restart();
    _ended = false;
  }

  Future<void> _addSlot() async {
    if (!_ctrl.canAddSlot) return;
    final app = AppScope.read(context);
    if (!await app.spend(GameScreen.slotCost)) {
      if (mounted) showToast(context, 'Not enough coins');
      return;
    }
    _ctrl.addSlot();
    _ended = false;
    _checkEnd();
  }

  Future<void> _hint() async {
    final app = AppScope.read(context);
    if (app.progress.coins < GameScreen.hintCost) {
      showToast(context, 'Not enough coins');
      return;
    }
    final screw = _ctrl.hint();
    if (screw == null) {
      showToast(context, 'No way out from here. Try Undo or Restart.');
      return;
    }
    await app.spend(GameScreen.hintCost);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final boss = widget.number % 10 == 0;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('back'),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Palette.ink,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Level ${widget.number}',
                        style: const TextStyle(
                          color: Palette.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (boss)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD81B60),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HARD',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const Spacer(),
                      CoinChip(coins: app.progress.coins),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                BoxesView(controller: _ctrl),
                const SizedBox(height: 12),
                TrayView(controller: _ctrl, onAddSlot: _addSlot),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: BoardView(controller: _ctrl, onScrewTap: _onTap),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Tool(
                        key: const Key('undo'),
                        icon: Icons.undo_rounded,
                        label: 'Undo',
                        color: Palette.purple,
                        onTap: _ctrl.canUndo && !_ctrl.isWon ? _undo : null,
                      ),
                      _Tool(
                        key: const Key('hint'),
                        icon: Icons.lightbulb_rounded,
                        label: 'Hint ${GameScreen.hintCost}',
                        color: const Color(0xFFF5A300),
                        onTap: _ctrl.isWon ? null : _hint,
                      ),
                      _Tool(
                        key: const Key('slot'),
                        icon: Icons.add_box_rounded,
                        label: 'Slot ${GameScreen.slotCost}',
                        color: Palette.green,
                        onTap: _ctrl.canAddSlot && !_ctrl.isWon
                            ? _addSlot
                            : null,
                      ),
                      _Tool(
                        key: const Key('restart'),
                        icon: Icons.refresh_rounded,
                        label: 'Restart',
                        color: Palette.blue,
                        onTap: _ctrl.isWon ? null : _restart,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const _Tool({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.cardBorder),
                boxShadow: Palette.softShadow(0.6),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Palette.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final int? stars;
  final List<Widget> actions;

  const _ResultDialog({
    required this.title,
    required this.subtitle,
    required this.actions,
    this.stars,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFFF6E0)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Palette.accent, width: 3),
          boxShadow: Palette.softShadow(1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              key: const Key('result-title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Palette.ink,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (stars != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 400 + i * 250),
                      curve: Curves.elasticOut,
                      builder: (_, t, c) => Transform.scale(scale: t, child: c),
                      child: Icon(
                        Icons.star_rounded,
                        size: i == 1 ? 64 : 50,
                        color: i < stars!
                            ? Palette.accent
                            : const Color(0xFFE4E0EE),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.inkSoft, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ...actions,
          ],
        ),
      ),
    );
  }
}
