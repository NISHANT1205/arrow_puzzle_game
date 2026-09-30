// lib/screens/game_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/level_generator.dart';
import '../engine/puzzle_board.dart';
import '../models/level.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/level_repository.dart';
import '../state/game_controller.dart';
import '../state/progress_provider.dart';
import '../widgets/arrow_board_view.dart';
import '../widgets/hearts_bar.dart';
import '../widgets/tier_badge.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.levelNumber});

  final int levelNumber;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  /// Null while the level is being generated.
  GameController? _current;
  GameController get _game => _current!;
  int _loadingLevel = 0;
  final TransformationController _zoom = TransformationController();
  bool _revived = false;
  bool _dialogOpen = false;
  Timer? _resultFallback;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load(widget.levelNumber);
  }

  Future<void> _load(int number) async {
    _loadingLevel = number;
    _loadError = null;
    final Level level;
    try {
      level = await LevelRepository.instance.level(number);
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
      return;
    }
    if (!mounted || _loadingLevel != number) return;
    setState(() {
      _current?.dispose();
      _current = GameController(level);
      _revived = false;
      _zoom.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _resultFallback?.cancel();
    _current?.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onMove(MoveResult result) {
    if (result is Escaped) {
      AudioService().playSlideOff();
      HapticService().lightTap();
    } else {
      AudioService().playBlockedTap();
      HapticService().blockedMove();
    }
    if (_game.status == GameStatus.won) {
      ref.read(progressProvider.notifier).completeLevel(_game.level.number);
    }
    if (_game.status != GameStatus.playing) {
      // The board reports when its animations end; this timer makes sure
      // the result shows even if that report never comes.
      _resultFallback?.cancel();
      _resultFallback = Timer(const Duration(milliseconds: 1800), _onSettled);
    }
  }

  void _onSettled() {
    if (!mounted || _dialogOpen || _current == null) return;
    switch (_game.status) {
      case GameStatus.won:
        AudioService().playLevelComplete();
        HapticService().levelComplete();
        _showResult(won: true);
      case GameStatus.lost:
        _showResult(won: false);
      case GameStatus.playing:
        break;
    }
  }

  Future<void> _showResult({required bool won}) async {
    _dialogOpen = true;
    _resultFallback?.cancel();
    final action = await showGeneralDialog<_ResultAction>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => _ResultCard(
        won: won,
        level: _game.level.number,
        mistakes: _game.mistakes,
        canRevive: !won && !_revived && !_game.stuck,
      ),
      transitionBuilder: (_, animation, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case _ResultAction.next:
        final next = _game.level.number + 1;
        setState(() {
          _current?.dispose();
          _current = null;
        });
        _load(next);
      case _ResultAction.retry:
        setState(() {
          _game.restart();
          _revived = false;
          _zoom.value = Matrix4.identity();
        });
      case _ResultAction.revive:
        setState(() {
          _revived = true;
          _game.revive();
        });
      case _ResultAction.home:
      case null:
        Navigator.of(context).pop();
    }
  }

  void _hint() {
    final arrow = _game.hint();
    AudioService().playUITap();
    if (arrow == null) return;
    HapticService().lightTap();
  }

  void _restart() {
    setState(() {
      _game.restart();
      _revived = false;
      _zoom.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final palette = dark ? BoardPalette.dark : BoardPalette.light;

    if (_current == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                level: _loadingLevel,
                onBack: () => Navigator.of(context).pop(),
                onRestart: () {},
              ),
              Expanded(
                child: Center(
                  child: _loadError == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not load this level.'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                setState(() => _loadError = null);
                                _load(_loadingLevel);
                              },
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _game,
          builder: (context, _) => Column(
            children: [
              _TopBar(
                level: _game.level.number,
                isCube: _game.level.isCube,
                onBack: () => Navigator.of(context).pop(),
                onRestart: _restart,
              ),
              const SizedBox(height: 4),
              HeartsBar(lives: _game.lives, maxLives: GameController.maxLives),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final level = _game.level;
                    final (boardW, boardH) = level.shape.extent;
                    const pad = 16.0;
                    final cell = [
                      (constraints.maxWidth - pad * 2) / boardW,
                      (constraints.maxHeight - pad * 2) / boardH,
                      56.0,
                    ].reduce((a, b) => a < b ? a : b);
                    return InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1,
                      maxScale: 6,
                      boundaryMargin: const EdgeInsets.all(120),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(
                          child: ArrowBoardView(
                            key: ValueKey(level.number),
                            controller: _game,
                            cellSize: cell,
                            palette: palette,
                            onMove: _onMove,
                            onSettled: _onSettled,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _BottomBar(
                remaining: _game.remainingArrows,
                total: _game.totalArrows,
                onHint: _hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.level,
    required this.onBack,
    required this.onRestart,
    this.isCube = false,
  });

  final int level;
  final bool isCube;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Level $level',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
                // Wraps onto a second line when both badges don't fit.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    if (LevelTier.forLevel(level) != LevelTier.normal)
                      TierBadge(tier: LevelTier.forLevel(level)),
                    if (isCube) const CubeBadge(),
                  ],
                ),
              ],
            ),
          ),
          _RoundIconButton(icon: Icons.refresh_rounded, onTap: onRestart),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.remaining,
    required this.total,
    required this.onHint,
  });

  final int remaining;
  final int total;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: .55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          Icon(Icons.north_east_rounded, size: 18, color: muted),
          const SizedBox(width: 6),
          Text(
            '$remaining / $total',
            style: theme.textTheme.titleMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onHint,
            icon: const Icon(Icons.lightbulb_rounded),
            label: const Text('Hint'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFC53D),
              foregroundColor: const Color(0xFF3A2A00),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}

enum _ResultAction { next, retry, revive, home }

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.won,
    required this.level,
    required this.mistakes,
    required this.canRevive,
  });

  final bool won;
  final int level;
  final int mistakes;
  final bool canRevive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = won ? const Color(0xFF22C55E) : const Color(0xFFF03E5A);
    return Center(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: accent.withValues(alpha: .14),
                child: Icon(
                  won ? Icons.check_rounded : Icons.heart_broken_rounded,
                  size: 44,
                  color: accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                won ? 'Level Complete!' : 'Out of lives',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                won
                    ? (mistakes == 0
                        ? 'Flawless! Level $level cleared.'
                        : 'Level $level cleared.')
                    : 'An arrow crashed one time too many.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: .7),
                ),
              ),
              const SizedBox(height: 22),
              if (won)
                _WideButton(
                  label: 'Next Level',
                  color: accent,
                  onTap: () => Navigator.pop(context, _ResultAction.next),
                )
              else ...[
                _WideButton(
                  label: 'Try Again',
                  color: const Color(0xFF2E90FF),
                  onTap: () => Navigator.pop(context, _ResultAction.retry),
                ),
                if (canRevive) ...[
                  const SizedBox(height: 10),
                  _WideButton(
                    label: 'Continue  +1 ♥',
                    color: accent,
                    onTap: () => Navigator.pop(context, _ResultAction.revive),
                  ),
                ],
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context, _ResultAction.home),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}
