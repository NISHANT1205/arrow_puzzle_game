import 'package:bus_jam/engine/game_state.dart';
import 'package:bus_jam/engine/level.dart';
import 'package:bus_jam/game/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Car 0 faces right at the left edge and is blocked by car 1, which faces
/// up and can leave straight away.
LevelDef tiny({
  List<int> queue = const [1, 1, 1, 1, 0, 0, 0, 0],
  int slots = 2,
}) => LevelDef(
  number: 1,
  cols: 4,
  rows: 3,
  slots: slots,
  vehicles: const [
    VehicleDef(1, 1, Dir.right, VehicleKind.car, 0),
    VehicleDef(2, 1, Dir.up, VehicleKind.car, 1),
  ],
  queue: queue,
  solution: const [1, 0],
);

void main() {
  test('vehicle cells follow its direction', () {
    const bus = VehicleDef(3, 0, Dir.down, VehicleKind.bus, 0);
    expect(bus.cells.toList(), [(3, 0), (3, -1), (3, -2), (3, -3)]);
    const car = VehicleDef(1, 1, Dir.right, VehicleKind.car, 0);
    expect(car.cells.toList(), [(1, 1), (0, 1)]);
    expect(car.tail, (0, 1));
  });

  test('blocked vehicles stay; clear ones park and passengers board', () {
    final g = GameState.initial(tiny());
    expect(g.blocker(0), 1);
    expect(g.tap(0), TapResult.blocked);
    expect(g.loc[0], VehicleLoc.lot);

    expect(g.tap(1), TapResult.parked);
    // All four colour-1 passengers board and the car leaves.
    expect(g.lastBoarded, 4);
    expect(g.loc[1], VehicleLoc.gone);
    expect(g.lastDeparted, [0]);
    expect(g.blocker(0), isNull);

    expect(g.tap(0), TapResult.parked);
    expect(g.isWon, isTrue);
  });

  test('vehicles wait in bays until their passengers reach the front', () {
    final g = GameState.initial(tiny(queue: const [0, 0, 0, 0, 1, 1, 1, 1]));
    g.tap(1);
    expect(g.loc[1], VehicleLoc.parked);
    expect(g.bays[0]!.filled, 0);
    g.tap(0);
    expect(g.isWon, isTrue);
  });

  test('full bays with no boarding is stuck', () {
    final g = GameState.initial(
      tiny(queue: const [0, 0, 0, 0, 1, 1, 1, 1], slots: 1),
    );
    g.tap(1);
    expect(g.hasFreeBay, isFalse);
    expect(g.isStuck, isTrue);
    expect(g.tap(0), TapResult.noBay);
    g.addBay();
    expect(g.isStuck, isFalse);
    g.tap(0);
    expect(g.isWon, isTrue);
  });

  test('controller undo, extra bay, restart and stars', () {
    final c = GameController(tiny());
    expect(c.tap(0), TapResult.blocked);
    expect(c.bumped, 0);
    expect(c.blocker, 1);
    expect(c.canUndo, isFalse);
    c.tap(1);
    expect(c.departed, [(0, 1)]);
    c.undo();
    expect(c.state.loc[1], VehicleLoc.lot);
    expect(c.stars, 2);
    c.addBay();
    expect(c.state.bays.length, 3);
    c.restart();
    expect(c.state.bays.length, 2);
    expect(c.stars, 3);
  });

  test('hint picks a vehicle that keeps the level winnable', () {
    final c = GameController(tiny(queue: const [0, 0, 0, 0, 1, 1, 1, 1]));
    expect(c.hint(), 1);
    // With a single bay this queue can never be finished.
    final lost = GameController(
      tiny(queue: const [0, 0, 0, 0, 1, 1, 1, 1], slots: 1),
    );
    expect(lost.hint(), isNull);
  });

  test('level json round-trips', () {
    final l = tiny();
    expect(LevelDef.fromJson(l.toJson()).toJson(), l.toJson());
  });
}
