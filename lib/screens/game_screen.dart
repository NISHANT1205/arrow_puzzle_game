import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/level.dart';
import '../services/audio_service.dart';
import '../services/level_repository.dart';
import '../state/game_provider.dart';
import '../state/progress_provider.dart';
import '../widgets/arrow_board_widget.dart';
import '../widgets/maze_arrow.dart';
import 'settings_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final Level level;

  const GameScreen({super.key, required this.level});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  final _audio = AudioService();
  late final AnimationController _entranceController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, .75, curve: Curves.easeOut),
    );
    _scale = Tween(begin: .92, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );
    Future.microtask(() {
      ref.read(gameProvider.notifier).startGame(widget.level);
      _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final scheme = Theme.of(context).colorScheme;
    if (game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = 1 - game.getRemainingArrows() / game.getTotalArrows();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFEAF3FF),
                Color(0xFFF8FAFD),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  level: widget.level,
                  onBack: _showExitDialog,
                  onSettings: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatPill(
                              icon: Icons.north_east_rounded,
                              label: 'LEFT',
                              value: '${game.getRemainingArrows()}',
                              color: const Color(0xFF2E90FF),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatPill(
                              icon: Icons.touch_app_rounded,
                              label: 'MOVES',
                              value: '${game.moveCount}',
                              color: const Color(0xFF0F1B4C),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatPill(
                              icon: Icons.bolt_rounded,
                              label: 'BLOCKED',
                              value: '${game.blockedTapCount}',
                              color: game.blockedTapCount == 0
                                  ? Colors.green
                                  : scheme.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            'CLEAR THE BOARD',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const Spacer(),
                          Text('${(progress * 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          builder: (_, value, __) => LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            color: const Color(0xFF2E90FF),
                            backgroundColor: const Color(0xFFDCE9F8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: ArrowPalette.border,
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ArrowBoardWidget(
                          level: widget.level,
                          onGameWon: () {
                            final completed = ref.read(gameProvider);
                            if (completed != null) {
                              _showCompleteDialog(completed);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                _Controls(
                  canUndo: game.undoHistory.isNotEmpty,
                  onUndo: () {
                    ref.read(gameProvider.notifier).undo();
                    _audio.playUITap();
                  },
                  onReset: () {
                    ref.read(gameProvider.notifier).reset();
                    _audio.playUITap();
                    _entranceController.forward(from: 0);
                  },
                  onHint: () {
                    ref.read(gameProvider.notifier).getHint();
                    _audio.playUITap();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.pause_circle_outline_rounded, size: 42),
        title: const Text('Pause puzzle?'),
        content: const Text('You can restart this level whenever you return.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(gameProvider.notifier).endGame();
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompleteDialog(GameState game) async {
    final stars = game.blockedTapCount == 0
        ? 3
        : game.blockedTapCount <= 2
            ? 2
            : 1;
    final confetti = ConfettiController(duration: const Duration(seconds: 2));
    confetti.play();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Stack(
        alignment: Alignment.topCenter,
        children: [
          Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: const CircleAvatar(
                      radius: 35,
                      child: Icon(Icons.check_rounded, size: 42),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Level cleared!',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              )),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 450 + i * 160),
                        curve: Curves.elasticOut,
                        builder: (_, value, child) => Transform.scale(
                          scale: value,
                          child: child,
                        ),
                        child: Icon(
                          i < stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 48,
                          color: i < stars ? Colors.amber : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      '${game.moveCount} moves  •  ${game.blockedTapCount} blocked'),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            ref.read(gameProvider.notifier).reset();
                            _entranceController.forward(from: 0);
                          },
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Replay'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openNext(game, dialogContext),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: .04,
            numberOfParticles: 18,
            gravity: .18,
          ),
        ],
      ),
    );
    confetti.dispose();
  }

  Future<void> _openNext(GameState game, BuildContext dialogContext) async {
    await ref.read(progressProvider.notifier).saveLevelProgress(
          widget.level.id,
          game.moveCount,
          game.blockedTapCount,
        );
    final next = await LevelRepository().getNextLevel(widget.level);
    ref.read(gameProvider.notifier).endGame();
    if (!mounted || !dialogContext.mounted) return;
    Navigator.pop(dialogContext);
    if (next == null) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GameScreen(level: next)),
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  final Level level;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  const _TopBar({
    required this.level,
    required this.onBack,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: onBack,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF0F1B4C),
                backgroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            ),
            Expanded(
              child: Column(
                children: [
                  Text('LEVEL ${level.id}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          )),
                  Text(level.pack,
                      style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: onSettings,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF0F1B4C),
                backgroundColor: Colors.white,
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
      );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF0F1B4C).withValues(alpha: .06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        )),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Text(value,
                      key: ValueKey(value),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Controls extends StatelessWidget {
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onHint;

  const _Controls({
    required this.canUndo,
    required this.onUndo,
    required this.onReset,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ControlButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              onTap: canUndo ? onUndo : null,
            ),
            _ControlButton(
              icon: Icons.refresh_rounded,
              label: 'Reset',
              onTap: onReset,
            ),
            _ControlButton(
              icon: Icons.lightbulb_rounded,
              label: 'Hint',
              highlighted: true,
              onTap: onHint,
            ),
          ],
        ),
      );
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: onTap == null ? .35 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 88,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: highlighted ? const Color(0xFF2E90FF) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: highlighted
                    ? const Color(0xFF2E90FF)
                    : const Color(0xFF0F1B4C).withValues(alpha: .08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: highlighted ? Colors.white : const Color(0xFF0F1B4C),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: highlighted ? Colors.white : const Color(0xFF0F1B4C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
