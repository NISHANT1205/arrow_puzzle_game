import 'package:flutter_test/flutter_test.dart';
import 'package:screw_jam/engine/game_state.dart';
import 'package:screw_jam/engine/level.dart';
import 'package:screw_jam/game/game_controller.dart';

/// Two plates: plate 1 (top) covers screw 0 of plate 0.
LevelDef tiny({int buffer = 5, List<int>? colors, List<int>? boxes}) {
  final c = colors ?? [0, 0, 0];
  return LevelDef(
    number: 1,
    cols: 4,
    rows: 4,
    bufferSize: buffer,
    activeBoxes: 2,
    plates: const [PlateDef(0, 0, 2, 1), PlateDef(0, 0, 1, 2)],
    screws: [
      ScrewDef(0, 0, 0, c[0]),
      ScrewDef(1, 0, 0, c[1]),
      ScrewDef(0, 1, 1, c[2]),
    ],
    boxes: boxes ?? const [0],
    solution: const [2, 1, 0],
  );
}

void main() {
  test('covered screws are blocked until the plate above falls', () {
    final g = GameState.initial(tiny());
    expect(g.isBlocked(0), isTrue);
    expect(g.tap(0), TapResult.blocked);
    expect(g.tap(2), TapResult.toBox);
    expect(g.plateAlive[1], isFalse, reason: 'last screw drops the plate');
    expect(g.isBlocked(0), isFalse);
    expect(g.tap(0), TapResult.toBox);
    expect(g.tap(1), TapResult.toBox);
    expect(g.isWon, isTrue);
  });

  test(
    'non-matching screws go to the tray and return when their box opens',
    () {
      // Box queue: colour 0 then colour 1 but only one box is open at a time.
      final l = LevelDef(
        number: 1,
        cols: 6,
        rows: 1,
        bufferSize: 3,
        activeBoxes: 1,
        plates: const [PlateDef(0, 0, 6, 1)],
        screws: const [
          ScrewDef(0, 0, 0, 1),
          ScrewDef(1, 0, 0, 0),
          ScrewDef(2, 0, 0, 0),
          ScrewDef(3, 0, 0, 0),
          ScrewDef(4, 0, 0, 1),
          ScrewDef(5, 0, 0, 1),
        ],
        boxes: const [0, 1],
        solution: const [],
      );
      final g = GameState.initial(l);
      expect(g.tap(0), TapResult.toBuffer);
      expect(g.buffer, [0]);
      g.tap(1);
      g.tap(2);
      expect(g.tap(3), TapResult.toBox);
      // Box 0 closed, box 1 opened and pulled screw 0 out of the tray.
      expect(g.buffer, isEmpty);
      expect(g.active[0]!.color, 1);
      expect(g.active[0]!.count, 1);
      g.tap(4);
      g.tap(5);
      expect(g.isWon, isTrue);
    },
  );

  test('full tray with no matching box is detected as stuck', () {
    final l = LevelDef(
      number: 1,
      cols: 6,
      rows: 1,
      bufferSize: 1,
      activeBoxes: 1,
      plates: const [PlateDef(0, 0, 6, 1)],
      screws: const [
        ScrewDef(0, 0, 0, 1),
        ScrewDef(1, 0, 0, 1),
        ScrewDef(2, 0, 0, 0),
        ScrewDef(3, 0, 0, 0),
        ScrewDef(4, 0, 0, 0),
        ScrewDef(5, 0, 0, 1),
      ],
      boxes: const [0, 1],
      solution: const [],
    );
    final g = GameState.initial(l);
    expect(g.tap(0), TapResult.toBuffer);
    expect(g.tap(1), TapResult.trayFull);
    expect(g.isStuck, isFalse, reason: 'colour 0 screws can still move');
    g.tap(2);
    g.tap(3);
    g.tap(4);
    expect(g.isWon, isFalse);
    expect(g.isStuck, isFalse);
  });

  test('controller undo, extra slot and restart', () {
    final c = GameController(tiny());
    expect(c.tap(0), TapResult.blocked);
    expect(c.shakeScrew, 0);
    expect(c.canUndo, isFalse);
    c.tap(2);
    expect(c.canUndo, isTrue);
    c.undo();
    expect(c.state.plateAlive[1], isTrue);
    expect(c.stars, 2);
    c.addSlot();
    expect(c.state.bufferCapacity, 6);
    expect(c.canAddSlot, isFalse);
    c.restart();
    expect(c.state.bufferCapacity, 5);
    expect(c.stars, 3);
  });

  test('hint suggests a move that keeps the level winnable', () {
    final c = GameController(tiny());
    final h = c.hint();
    expect(h, isIn([1, 2]), reason: 'both uncovered screws are safe');
    expect(c.hintScrew, h);
    c.tap(h!);
    expect(c.hintScrew, isNull);
  });

  test('level json round-trips', () {
    final l = tiny();
    final back = LevelDef.fromJson(l.toJson());
    expect(back.toJson(), l.toJson());
  });
}
