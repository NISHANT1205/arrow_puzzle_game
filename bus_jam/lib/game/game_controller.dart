import 'package:flutter/foundation.dart';

import '../engine/game_state.dart';
import '../engine/level.dart';
import '../engine/solver.dart';

/// Wraps [GameState] with undo, boosters and one-shot animation events.
class GameController extends ChangeNotifier {
  static const maxExtraBays = 2;

  final LevelDef level;
  GameState state;
  final List<GameState> _history = [];

  int undosUsed = 0;
  int hintsUsed = 0;

  /// Increments on every change so widgets can key one-shot animations.
  int stamp = 0;

  /// Vehicle that just drove out of the lot.
  int? exiting;

  /// Vehicle that bumped into [blocker] on its way out.
  int? bumped;
  int? blocker;

  /// (bay, vehicle) pairs that filled up and drove off on the last tap.
  List<(int, int)> departed = const [];
  int? hintVehicle;
  TapResult? lastResult;

  GameController(this.level) : state = GameState.initial(level);

  bool get isWon => state.isWon;
  bool get isStuck => state.isStuck;
  bool get canUndo => _history.isNotEmpty;
  bool get canAddBay => state.extraBays < maxExtraBays;

  int get boostersUsed => undosUsed + hintsUsed + state.extraBays;

  int get stars {
    if (boostersUsed == 0) return 3;
    if (boostersUsed <= 2) return 2;
    return 1;
  }

  TapResult tap(int vehicle) {
    final before = state.copy();
    final baysBefore = [for (final b in state.bays) b?.vehicle];
    final r = state.tap(vehicle);
    stamp++;
    lastResult = r;
    exiting = null;
    bumped = null;
    blocker = null;
    departed = const [];
    if (r == TapResult.parked) {
      _history.add(before);
      hintVehicle = null;
      exiting = vehicle;
      departed = [
        for (final bay in state.lastDeparted) (bay, baysBefore[bay] ?? vehicle),
      ];
    } else if (r == TapResult.blocked) {
      bumped = vehicle;
      blocker = state.blocker(vehicle);
    }
    notifyListeners();
    return r;
  }

  void undo() {
    if (_history.isEmpty) return;
    state = _history.removeLast();
    undosUsed++;
    _clearEvents();
  }

  void addBay() {
    if (!canAddBay) return;
    state.addBay();
    for (final h in _history) {
      h.addBay();
    }
    _clearEvents();
  }

  void restart() {
    state = GameState.initial(level);
    _history.clear();
    undosUsed = 0;
    hintsUsed = 0;
    _clearEvents();
  }

  /// A vehicle to tap that keeps the level winnable, or null if the current
  /// position is already lost.
  int? hint() {
    final path = Solver(nodeLimit: 30000).solve(state);
    if (path == null || path.isEmpty) return null;
    hintsUsed++;
    hintVehicle = path.first;
    stamp++;
    notifyListeners();
    return hintVehicle;
  }

  void _clearEvents() {
    stamp++;
    exiting = null;
    bumped = null;
    blocker = null;
    departed = const [];
    hintVehicle = null;
    lastResult = null;
    notifyListeners();
  }
}
