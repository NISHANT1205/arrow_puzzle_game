import 'package:flutter/foundation.dart';

import '../engine/game_state.dart';
import '../engine/level.dart';
import '../engine/solver.dart';

/// Wraps [GameState] with undo, boosters and UI event stamps.
class GameController extends ChangeNotifier {
  static const maxExtraSlots = 1;

  final LevelDef level;
  GameState state;
  final List<GameState> _history = [];

  int moves = 0;
  int undosUsed = 0;
  int hintsUsed = 0;

  /// Increments on every change so widgets can key one-shot animations.
  int stamp = 0;

  int? shakeScrew;
  int? hintScrew;
  List<int> fallenPlates = const [];
  List<int> completedSlots = const [];
  TapResult? lastResult;

  GameController(this.level) : state = GameState.initial(level);

  bool get isWon => state.isWon;
  bool get isStuck => state.isStuck;
  bool get canUndo => _history.isNotEmpty;
  bool get canAddSlot => state.extraSlots < maxExtraSlots;

  int get boostersUsed => undosUsed + hintsUsed + state.extraSlots;

  int get stars {
    if (boostersUsed == 0) return 3;
    if (boostersUsed <= 2) return 2;
    return 1;
  }

  TapResult tap(int screw) {
    final before = state.copy();
    final r = state.tap(screw);
    stamp++;
    lastResult = r;
    shakeScrew = null;
    fallenPlates = const [];
    completedSlots = const [];
    if (r == TapResult.toBox || r == TapResult.toBuffer) {
      _history.add(before);
      moves++;
      hintScrew = null;
      fallenPlates = List.of(state.lastFallenPlates);
      completedSlots = List.of(state.lastCompletedSlots);
    } else if (r == TapResult.blocked || r == TapResult.trayFull) {
      shakeScrew = screw;
    }
    notifyListeners();
    return r;
  }

  void undo() {
    if (_history.isEmpty) return;
    final extra = state.extraSlots;
    state = _history.removeLast()..extraSlots = extra;
    undosUsed++;
    _clearEvents();
  }

  void addSlot() {
    if (!canAddSlot) return;
    state.extraSlots++;
    for (final h in _history) {
      h.extraSlots = state.extraSlots;
    }
    _clearEvents();
  }

  void restart() {
    state = GameState.initial(level);
    _history.clear();
    moves = 0;
    undosUsed = 0;
    hintsUsed = 0;
    _clearEvents();
  }

  /// Finds a screw that keeps the level winnable, or null when the current
  /// position is lost (the player should undo or restart).
  int? hint() {
    final path = Solver(nodeLimit: 40000).solve(state);
    if (path == null || path.isEmpty) return null;
    hintsUsed++;
    hintScrew = path.first;
    stamp++;
    notifyListeners();
    return hintScrew;
  }

  void _clearEvents() {
    stamp++;
    shakeScrew = null;
    hintScrew = null;
    fallenPlates = const [];
    completedSlots = const [];
    lastResult = null;
    notifyListeners();
  }
}
