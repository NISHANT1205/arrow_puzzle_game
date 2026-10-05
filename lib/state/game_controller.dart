// lib/state/game_controller.dart

import 'package:flutter/foundation.dart';

import '../engine/puzzle_board.dart';
import '../models/arrow_path.dart';
import '../models/level.dart';

enum GameStatus { playing, won, lost }

/// One play-through of a level: the board, lives, hints and win/lose state.
class GameController extends ChangeNotifier {
  GameController(this.level) {
    _start();
  }

  static const int maxLives = 3;

  final Level level;

  late PuzzleBoard board;
  int lives = maxLives;
  int moves = 0;
  int mistakes = 0;
  int hintsUsed = 0;
  GameStatus status = GameStatus.playing;

  /// True when the game ended because no arrow could move any more.
  bool stuck = false;

  /// Arrow currently highlighted by a hint.
  int? hintArrowId;

  int get totalArrows => level.arrows.length;
  int get remainingArrows => board.count;
  double get progress =>
      totalArrows == 0 ? 1 : (totalArrows - remainingArrows) / totalArrows;

  void _start() {
    board = PuzzleBoard.forLevel(level);
    lives = maxLives;
    moves = 0;
    mistakes = 0;
    hintsUsed = 0;
    hintArrowId = null;
    stuck = false;
    status = GameStatus.playing;
  }

  /// Taps [arrow]. Escaping removes it; hitting another arrow costs a life.
  /// Returns null when the tap is ignored (game over or arrow already gone).
  MoveResult? tap(ArrowPath arrow) {
    if (status != GameStatus.playing) return null;
    if (board.arrowById(arrow.id) == null) return null;

    final result = board.tap(arrow);
    moves++;
    if (result is Escaped) {
      if (hintArrowId == arrow.id) hintArrowId = null;
      if (board.isCleared) {
        status = GameStatus.won;
      } else if (board.freeArrows().isEmpty) {
        // Never happens with checked levels, but a board with no way out
        // must end the game instead of leaving the player stuck.
        stuck = true;
        status = GameStatus.lost;
      }
    } else {
      mistakes++;
      lives--;
      if (lives <= 0) {
        lives = 0;
        status = GameStatus.lost;
      }
    }
    notifyListeners();
    return result;
  }

  /// Highlights an arrow that can escape right now.
  ArrowPath? hint() {
    if (status != GameStatus.playing) return null;
    final current = hintArrowId == null ? null : board.arrowById(hintArrowId!);
    if (current != null && board.canEscape(current)) return current;

    final free = board.freeArrows();
    if (free.isEmpty) return null;
    // Prefer the arrow closest to the top-left, so hints read naturally.
    free.sort((a, b) {
      final byRow = a.head.row.compareTo(b.head.row);
      return byRow != 0 ? byRow : a.head.col.compareTo(b.head.col);
    });
    hintArrowId = free.first.id;
    hintsUsed++;
    notifyListeners();
    return free.first;
  }

  /// Gives one more life after losing, so the player can keep going.
  void revive() {
    if (status != GameStatus.lost || stuck) return;
    lives = 1;
    status = GameStatus.playing;
    notifyListeners();
  }

  void restart() {
    _start();
    notifyListeners();
  }

  /// The arrow drawn under a board cell, if any.
  ArrowPath? arrowAt(Cell cell) => board.arrowAt(cell);
}
