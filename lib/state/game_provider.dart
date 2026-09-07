// lib/state/game_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/arrow_board.dart';
import '../models/level.dart';

/// Represents the state of a game session
class GameState {
  final Level level;
  final ArrowBoard board;
  final List<Arrow> undoHistory; // Stack of removed arrows (in reverse order)
  final int moveCount;
  final int blockedTapCount;
  final bool isWon;
  final Arrow? hintedArrow;

  const GameState({
    required this.level,
    required this.board,
    required this.undoHistory,
    required this.moveCount,
    required this.blockedTapCount,
    required this.isWon,
    this.hintedArrow,
  });

  /// Create initial game state for a level
  factory GameState.initial(Level level) {
    return GameState(
      level: level,
      board: ArrowBoard(gridSize: level.gridSize, initialArrows: level.arrows),
      undoHistory: [],
      moveCount: 0,
      blockedTapCount: 0,
      isWon: false,
      hintedArrow: null,
    );
  }

  /// Create a copy with optional field overrides
  GameState copyWith({
    Level? level,
    ArrowBoard? board,
    List<Arrow>? undoHistory,
    int? moveCount,
    int? blockedTapCount,
    bool? isWon,
    Arrow? hintedArrow,
    bool clearHint = false,
  }) {
    return GameState(
      level: level ?? this.level,
      board: board ?? this.board,
      undoHistory: undoHistory ?? this.undoHistory,
      moveCount: moveCount ?? this.moveCount,
      blockedTapCount: blockedTapCount ?? this.blockedTapCount,
      isWon: isWon ?? this.isWon,
      hintedArrow: clearHint ? null : (hintedArrow ?? this.hintedArrow),
    );
  }

  /// Get remaining arrow count
  int getRemainingArrows() => board.arrows.length;

  /// Get original arrow count
  int getTotalArrows() => level.arrows.length;

  /// Get arrows that can be tapped
  List<Arrow> getTappableArrows() => board.findTappableArrows();

  @override
  String toString() =>
      'GameState(level=${level.id}, remaining=${getRemainingArrows()}, moves=$moveCount, blocked=$blockedTapCount)';
}

/// Notifier for game state
class GameNotifier extends StateNotifier<GameState?> {
  GameNotifier() : super(null);

  /// Start a new game with a level
  void startGame(Level level) {
    state = GameState.initial(level);
  }

  /// Try to tap an arrow at the given position
  /// Returns true if successful, false if blocked
  bool tapArrow(int row, int col) {
    if (state == null) return false;

    final board = state!.board.copy();
    final arrow = board.getArrowAt(row, col);

    if (arrow == null) return false;

    // Check if path is clear
    if (!board.isPathClear(arrow)) {
      // Blocked tap - no state change, just increment counter
      state = state!.copyWith(
        blockedTapCount: state!.blockedTapCount + 1,
        clearHint: true,
      );
      return false;
    }

    // Path is clear - remove the arrow
    board.tapArrow(row, col);

    // Update state
    final newUndoHistory = [...state!.undoHistory, arrow];
    final newMoveCount = state!.moveCount + 1;
    final isWon = board.isCleared();

    state = state!.copyWith(
      board: board,
      undoHistory: newUndoHistory,
      moveCount: newMoveCount,
      isWon: isWon,
      clearHint: true,
    );

    return true;
  }

  /// Undo the last move
  void undo() {
    if (state == null || state!.undoHistory.isEmpty) return;

    final newUndoHistory = state!.undoHistory.toList();
    final arrowToRestore = newUndoHistory.removeLast();

    final board = state!.board.copy();
    board.restoreArrow(arrowToRestore);

    state = state!.copyWith(
      board: board,
      undoHistory: newUndoHistory,
      moveCount: state!.moveCount - 1,
      isWon: false,
      clearHint: true,
    );
  }

  /// Reset the level to its starting state
  void reset() {
    if (state == null) return;

    state = GameState.initial(state!.level);
  }

  /// Reveal a hint (return a tappable arrow position, or null if none available)
  Arrow? getHint() {
    if (state == null) return null;

    final tappableArrows = state!.getTappableArrows();
    if (tappableArrows.isNotEmpty) {
      final hint = tappableArrows.first;
      state = state!.copyWith(hintedArrow: hint);
      return hint;
    }
    return null;
  }

  /// End the current game
  void endGame() {
    state = null;
  }
}

/// Provider for game state
final gameProvider = StateNotifierProvider<GameNotifier, GameState?>((ref) {
  return GameNotifier();
});

/// Provider for current game level (convenience accessor)
final currentGameLevelProvider = Provider<Level?>((ref) {
  final gameState = ref.watch(gameProvider);
  return gameState?.level;
});

/// Provider for remaining arrows in current game
final remainingArrowsProvider = Provider<int>((ref) {
  final gameState = ref.watch(gameProvider);
  return gameState?.getRemainingArrows() ?? 0;
});

/// Provider for tappable arrows
final tappableArrowsProvider = Provider<List<Arrow>>((ref) {
  final gameState = ref.watch(gameProvider);
  return gameState?.getTappableArrows() ?? [];
});

/// Provider for game progress percentage (arrows cleared)
final gameProgressPercentageProvider = Provider<double>((ref) {
  final gameState = ref.watch(gameProvider);
  if (gameState == null) return 0.0;

  final total = gameState.getTotalArrows();
  if (total == 0) return 1.0;

  final remaining = gameState.getRemainingArrows();
  return (total - remaining) / total;
});
