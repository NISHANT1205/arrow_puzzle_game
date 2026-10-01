import 'level.dart';

enum VehicleLoc { lot, parked, gone }

enum TapResult { parked, blocked, noBay, invalid }

/// A vehicle waiting in a station bay.
class Bay {
  final int vehicle;
  int filled;
  Bay(this.vehicle, [this.filled = 0]);
  Bay copy() => Bay(vehicle, filled);
}

/// Mutable game state for one play-through of a [LevelDef].
class GameState {
  final LevelDef level;
  final List<VehicleLoc> loc;

  /// Station bays; null is an empty bay.
  final List<Bay?> bays;

  /// Index of the passenger at the front of the queue.
  int front;
  int extraBays;

  /// Vehicle index per lot cell, -1 when empty.
  final List<int> grid;

  GameState._(
    this.level,
    this.loc,
    this.bays,
    this.front,
    this.extraBays,
    this.grid,
  );

  factory GameState.initial(LevelDef level) {
    final grid = List<int>.filled(level.cols * level.rows, -1);
    for (var i = 0; i < level.vehicles.length; i++) {
      for (final (x, y) in level.vehicles[i].cells) {
        grid[y * level.cols + x] = i;
      }
    }
    return GameState._(
      level,
      List.filled(level.vehicles.length, VehicleLoc.lot),
      List<Bay?>.filled(level.slots, null, growable: true),
      0,
      0,
      grid,
    );
  }

  GameState copy() => GameState._(
    level,
    List.of(loc),
    bays.map((b) => b?.copy()).toList(),
    front,
    extraBays,
    List.of(grid),
  );

  bool get isWon => loc.every((l) => l == VehicleLoc.gone);

  int get passengersLeft => level.queue.length - front;

  bool get hasFreeBay => bays.any((b) => b == null);

  /// The first vehicle in the way of [vehicle]'s exit, or null if clear.
  int? blocker(int vehicle) {
    final v = level.vehicles[vehicle];
    var x = v.x + v.dir.dx, y = v.y + v.dir.dy;
    while (x >= 0 && y >= 0 && x < level.cols && y < level.rows) {
      final o = grid[y * level.cols + x];
      if (o >= 0) return o;
      x += v.dir.dx;
      y += v.dir.dy;
    }
    return null;
  }

  bool canExit(int vehicle) =>
      loc[vehicle] == VehicleLoc.lot && blocker(vehicle) == null;

  List<int> legalMoves() {
    if (!hasFreeBay) return [];
    return [
      for (var i = 0; i < level.vehicles.length; i++)
        if (canExit(i)) i,
    ];
  }

  bool get isStuck => !isWon && legalMoves().isEmpty;

  /// Bays whose vehicle filled up and left during the last [tap].
  final List<int> lastDeparted = [];

  /// Passengers that boarded during the last [tap].
  int lastBoarded = 0;

  /// Bay the tapped vehicle parked in.
  int? lastBay;

  TapResult tap(int vehicle) {
    lastDeparted.clear();
    lastBoarded = 0;
    lastBay = null;
    if (vehicle < 0 ||
        vehicle >= level.vehicles.length ||
        loc[vehicle] != VehicleLoc.lot) {
      return TapResult.invalid;
    }
    if (blocker(vehicle) != null) return TapResult.blocked;
    final bay = bays.indexWhere((b) => b == null);
    if (bay < 0) return TapResult.noBay;

    for (final (x, y) in level.vehicles[vehicle].cells) {
      grid[y * level.cols + x] = -1;
    }
    loc[vehicle] = VehicleLoc.parked;
    bays[bay] = Bay(vehicle);
    lastBay = bay;
    _board();
    return TapResult.parked;
  }

  /// Front passengers board matching vehicles until nobody can.
  void _board() {
    while (front < level.queue.length) {
      final color = level.queue[front];
      int? target;
      for (var i = 0; i < bays.length; i++) {
        final b = bays[i];
        if (b == null) continue;
        final v = level.vehicles[b.vehicle];
        if (v.color == color && b.filled < v.seats) {
          target = i;
          break;
        }
      }
      if (target == null) return;
      final b = bays[target]!;
      b.filled++;
      front++;
      lastBoarded++;
      if (b.filled == level.vehicles[b.vehicle].seats) {
        loc[b.vehicle] = VehicleLoc.gone;
        bays[target] = null;
        lastDeparted.add(target);
      }
    }
  }

  void addBay() {
    bays.add(null);
    extraBays++;
  }

  String get key {
    final sb = StringBuffer();
    for (final l in loc) {
      sb.write(l.index);
    }
    sb.write('|$front|');
    final parked = [
      for (final b in bays)
        if (b != null) '${b.vehicle}:${b.filled}',
    ]..sort();
    sb.write(parked.join(','));
    sb.write('|${bays.length}');
    return sb.toString();
  }
}
