import 'level.dart';

enum ScrewLocation { board, buffer, box }

enum TapResult { toBox, toBuffer, blocked, trayFull, invalid }

class ActiveBox {
  final int color;
  int count;

  ActiveBox(this.color, [this.count = 0]);

  ActiveBox copy() => ActiveBox(color, count);
}

/// Mutable game state for one play-through of a [LevelDef].
///
/// All rules live here so the UI, the solver and the tests share one
/// implementation.
class GameState {
  final LevelDef level;
  final List<ScrewLocation> screwLoc;
  final List<bool> plateAlive;
  final List<int> plateScrewsLeft;

  /// Open boxes; `null` means the slot is empty because the queue ran out.
  final List<ActiveBox?> active;
  final List<int> buffer;
  int nextBox;
  int extraSlots;
  int boxesDone;

  GameState._(
    this.level,
    this.screwLoc,
    this.plateAlive,
    this.plateScrewsLeft,
    this.active,
    this.buffer,
    this.nextBox,
    this.extraSlots,
    this.boxesDone,
  );

  factory GameState.initial(LevelDef level) {
    final left = List<int>.filled(level.plates.length, 0);
    for (final s in level.screws) {
      left[s.plate]++;
    }
    final active = <ActiveBox?>[];
    var next = 0;
    for (var i = 0; i < level.activeBoxes; i++) {
      if (next < level.boxes.length) {
        active.add(ActiveBox(level.boxes[next++]));
      } else {
        active.add(null);
      }
    }
    return GameState._(
      level,
      List.filled(level.screws.length, ScrewLocation.board),
      // A plate without screws would never fall, so treat it as gone.
      List.generate(level.plates.length, (i) => left[i] > 0),
      left,
      active,
      [],
      next,
      0,
      0,
    );
  }

  GameState copy() => GameState._(
    level,
    List.of(screwLoc),
    List.of(plateAlive),
    List.of(plateScrewsLeft),
    active.map((b) => b?.copy()).toList(),
    List.of(buffer),
    nextBox,
    extraSlots,
    boxesDone,
  );

  int get bufferCapacity => level.bufferSize + extraSlots;

  bool get isWon => boxesDone == level.boxes.length;

  bool isBlocked(int screw) {
    final s = level.screws[screw];
    for (var p = s.plate + 1; p < level.plates.length; p++) {
      if (plateAlive[p] && level.plates[p].covers(s.x, s.y)) return true;
    }
    return false;
  }

  bool isFree(int screw) =>
      screwLoc[screw] == ScrewLocation.board && !isBlocked(screw);

  int? _openBoxFor(int color) {
    for (var i = 0; i < active.length; i++) {
      final b = active[i];
      if (b != null && b.color == color && b.count < LevelDef.boxCapacity) {
        return i;
      }
    }
    return null;
  }

  /// Where a free screw would go right now, or `null` if nowhere.
  TapResult? destinationOf(int screw) {
    final color = level.screws[screw].color;
    if (_openBoxFor(color) != null) return TapResult.toBox;
    if (buffer.length < bufferCapacity) return TapResult.toBuffer;
    return null;
  }

  List<int> legalMoves() {
    final moves = <int>[];
    final canBuffer = buffer.length < bufferCapacity;
    for (var i = 0; i < level.screws.length; i++) {
      if (!isFree(i)) continue;
      if (canBuffer || _openBoxFor(level.screws[i].color) != null) {
        moves.add(i);
      }
    }
    return moves;
  }

  bool get isStuck => !isWon && legalMoves().isEmpty;

  /// Plates that fell during the last successful [tap].
  final List<int> lastFallenPlates = [];

  /// Box slots that were completed (and refilled) during the last [tap].
  final List<int> lastCompletedSlots = [];

  TapResult tap(int screw) {
    lastFallenPlates.clear();
    lastCompletedSlots.clear();
    if (screw < 0 ||
        screw >= level.screws.length ||
        screwLoc[screw] != ScrewLocation.board) {
      return TapResult.invalid;
    }
    if (isBlocked(screw)) return TapResult.blocked;

    final s = level.screws[screw];
    final slot = _openBoxFor(s.color);
    TapResult result;
    if (slot != null) {
      screwLoc[screw] = ScrewLocation.box;
      active[slot]!.count++;
      result = TapResult.toBox;
    } else if (buffer.length < bufferCapacity) {
      screwLoc[screw] = ScrewLocation.buffer;
      buffer.add(screw);
      result = TapResult.toBuffer;
    } else {
      return TapResult.trayFull;
    }

    plateScrewsLeft[s.plate]--;
    if (plateScrewsLeft[s.plate] == 0) {
      plateAlive[s.plate] = false;
      lastFallenPlates.add(s.plate);
    }
    _settle();
    return result;
  }

  /// Closes full boxes, opens the next ones from the queue and pulls matching
  /// screws out of the tray until nothing changes.
  void _settle() {
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < active.length; i++) {
        final b = active[i];
        if (b != null && b.count == LevelDef.boxCapacity) {
          boxesDone++;
          lastCompletedSlots.add(i);
          active[i] = nextBox < level.boxes.length
              ? ActiveBox(level.boxes[nextBox++])
              : null;
          changed = true;
        }
      }
      for (var k = 0; k < buffer.length; k++) {
        final screw = buffer[k];
        final slot = _openBoxFor(level.screws[screw].color);
        if (slot != null) {
          buffer.removeAt(k);
          k--;
          screwLoc[screw] = ScrewLocation.box;
          active[slot]!.count++;
          changed = true;
        }
      }
    }
  }

  /// Compact key used by the solver to avoid revisiting states.
  String get key {
    final sb = StringBuffer();
    for (final l in screwLoc) {
      sb.write(l == ScrewLocation.board ? '1' : '0');
    }
    sb.write('|');
    final bc = buffer.map((s) => level.screws[s].color).toList()..sort();
    sb.write(bc.join(','));
    sb.write('|$nextBox|$extraSlots|');
    for (final b in active) {
      sb.write(b == null ? '-' : '${b.color}:${b.count}');
      sb.write(';');
    }
    return sb.toString();
  }
}
