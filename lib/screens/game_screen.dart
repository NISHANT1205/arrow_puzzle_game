// lib/screens/game_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/level_generator.dart';
import '../engine/puzzle_board.dart';
import '../models/level.dart';
import '../services/audio_service.dart';
import '../services/backend_sync_service.dart';
import '../services/player_session_service.dart';
import '../services/local_storage_service.dart';
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
  Matrix4 _initialZoom = Matrix4.identity();
  Size? _zoomViewport;
  int? _zoomLevel;
  bool _dialogOpen = false;
  Timer? _resultFallback;
  String? _loadError;
  String _attemptId = "";

  void _record(String type, [Map<String, Object> details = const {}]) {
    if (_current == null) return;
    BackendSyncService.instance.record(type, {
      "attemptId": _attemptId,
      "level": _game.level.number,
      "moves": _game.moves,
      "mistakes": _game.mistakes,
      "hintsUsed": _game.hintsUsed,
      "lives": _game.lives,
      "remainingArrows": _game.remainingArrows,
      "status": _game.status.name,
      "isCube": _game.level.isCube,
      ...details,
    });
  }

  Future<void> _beginAttempt() async {
    _attemptId = DateTime.now().microsecondsSinceEpoch.toString();
    PlayerSessionService.instance.setActivity(PlayerActivity.playing);
    _record("start");
    final storage = LocalStorageService();
    final games = await storage.loadInt("backend_games_played");
    await storage.saveInt("backend_games_played", games + 1);
  }

  @override
  void initState() {
    super.initState();
    _load(widget.levelNumber);
  }

  Future<void> _load(int number) async {
    AudioService().stopAll();
    AudioService().playUITap();
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
      _zoomViewport = null;
      _zoom.value = Matrix4.identity();
    });
    unawaited(_beginAttempt());
  }

  @override
  void dispose() {
    _record("leave");
    PlayerSessionService.instance.setActivity(PlayerActivity.home);
    _resultFallback?.cancel();
    _current?.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onMove(MoveResult result) {
    _record("move", {
      "arrowId": result.arrow.id,
      "escaped": result is Escaped,
      if (result is Blocked) "blockerId": result.blocker.id,
    });
    if (_game.status != GameStatus.playing) {
      PlayerSessionService.instance.setActivity(PlayerActivity.paused);
      _record("result");
    }
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
        AudioService().playGameOver();
        _showResult(won: false);
      case GameStatus.playing:
        break;
    }
  }

  Future<void> _showResult({required bool won}) async {
    _dialogOpen = true;
    PlayerSessionService.instance.setActivity(PlayerActivity.paused);
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
        _record("restart");
        setState(() {
          _game.restart();
          _zoom.value = _initialZoom.clone();
        });
        unawaited(_beginAttempt());
      case _ResultAction.home:
      case null:
        Navigator.of(context).pop();
    }
  }

  void _hint() {
    final arrow = _game.hint();
    if (arrow != null) _record("hint", {"arrowId": arrow.id});
    AudioService().playHint();
    if (arrow == null) return;
    HapticService().lightTap();
  }

  void _restart() {
    _record("restart");
    AudioService().stopAll();
    AudioService().playUITap();
    setState(() {
      _game.restart();
      _zoom.value = _initialZoom.clone();
    });
    unawaited(_beginAttempt());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BoardPalette.fromScheme(theme.colorScheme);

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
                    if (level.isCube) {
                      // The cube handles its own turning and zooming.
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: ArrowBoardView(
                              key: ValueKey(level.number),
                              controller: _game,
                              cellSize: cell,
                              palette: palette,
                              onMove: _onMove,
                              onSettled: _onSettled,
                            ),
                          ),
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 4,
                            child: _TurnHint(),
                          ),
                        ],
                      );
                    }
                    if (level.number >= 76) {
                      // Keep large maps at a readable world size. Start with
                      // the entire map fitted into the available viewport.
                      const worldCell = 40.0;
                      final mapW = boardW * worldCell + pad * 2;
                      final mapH = boardH * worldCell + pad * 2;
                      final fit = [
                        constraints.maxWidth / mapW,
                        constraints.maxHeight / mapH,
                        1.0,
                      ].reduce((a, b) => a < b ? a : b);
                      final viewport =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      if (_zoomViewport != viewport ||
                          _zoomLevel != level.number) {
                        _zoomViewport = viewport;
                        _zoomLevel = level.number;
                        _initialZoom = Matrix4.identity()
                          ..translateByDouble((viewport.width - mapW * fit) / 2,
                              (viewport.height - mapH * fit) / 2, 0, 1)
                          ..scaleByDouble(fit, fit, fit, 1);
                        _zoom.value = _initialZoom.clone();
                      }
                      return Stack(children: [
                        Positioned.fill(
                            child: InteractiveViewer(
                          transformationController: _zoom,
                          constrained: false,
                          minScale: fit,
                          maxScale: 3,
                          boundaryMargin: const EdgeInsets.all(120),
                          child: SizedBox(
                            width: mapW,
                            height: mapH,
                            child: Center(
                                child: ArrowBoardView(
                              key: ValueKey(level.number),
                              controller: _game,
                              cellSize: worldCell,
                              palette: palette,
                              onMove: _onMove,
                              onSettled: _onSettled,
                            )),
                          ),
                        )),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filledTonal(
                            tooltip: 'Show full map',
                            onPressed: () {
                              AudioService().playUITap();
                              _zoom.value = _initialZoom.clone();
                            },
                            icon: const Icon(Icons.fit_screen_rounded),
                          ),
                        ),
                      ]);
                    }
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
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
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
        onTap: () {
          AudioService().playUITap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}

enum _ResultAction { next, retry, home }

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.won,
    required this.level,
    required this.mistakes,
  });

  final bool won;
  final int level;
  final int mistakes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = won ? theme.colorScheme.primary : theme.colorScheme.error;
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
                  label: level >= LevelRepository.instance.bundledCount
                      ? 'Back to Home'
                      : 'Next Level',
                  color: accent,
                  onTap: () => Navigator.pop(
                      context,
                      level >= LevelRepository.instance.bundledCount
                          ? _ResultAction.home
                          : _ResultAction.next),
                )
              else ...[
                _WideButton(
                  label: 'Try Again',
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.pop(context, _ResultAction.retry),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  AudioService().playUITap();
                  Navigator.pop(context, _ResultAction.home);
                },
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
        onPressed: () {
          AudioService().playUITap();
          onTap();
        },
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == Theme.of(context).colorScheme.error
              ? Theme.of(context).colorScheme.onError
              : Theme.of(context).colorScheme.onPrimary,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}

/// "Drag to turn the cube" note under a cube.
class _TurnHint extends StatelessWidget {
  const _TurnHint();

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: .45);
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.threed_rotation_rounded, size: 16, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Drag to turn · pinch to zoom',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
