import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/arrow_path.dart';
import 'package:arrow_puzzle/models/level.dart';
import 'package:arrow_puzzle/models/level_codec.dart';
import 'package:arrow_puzzle/state/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

ArrowPath arrow(int id, List<List<int>> cells) =>
    ArrowPath(id: id, cells: [for (final c in cells) Cell(c[0], c[1])]);

void main() {
  // 4x4 board:
  //  A: (1,0)->(1,1) pointing right, runs into B's body at (1,3).
  //  B: (3,3)->(2,3)->(1,3)->(0,3) pointing up, free.
  final a = arrow(0, [
    [1, 0],
    [1, 1],
  ]);
  final b = arrow(1, [
    [3, 3],
    [2, 3],
    [1, 3],
    [0, 3],
  ]);
  final level = Level(number: 1, rows: 4, cols: 4, arrows: [a, b]);

  test('direction follows the last segment of the body', () {
    expect(a.direction, Dir.right);
    expect(b.direction, Dir.up);
    final bent = arrow(2, [
      [0, 0],
      [1, 0],
      [1, 1],
    ]);
    expect(bent.direction, Dir.right);
  });

  test('blocked arrow reports the blocker and the free distance', () {
    final board = PuzzleBoard(rows: 4, cols: 4, arrows: [a, b]);
    final result = board.evaluate(a);
    expect(result, isA<Blocked>());
    result as Blocked;
    expect(result.blocker.id, b.id);
    expect(result.freeSteps, 1);
    expect(result.hitCell, const Cell(1, 3));
  });

  test('escaping clears the lane for others', () {
    final board = PuzzleBoard(rows: 4, cols: 4, arrows: [a, b]);
    final first = board.tap(b);
    expect(first, isA<Escaped>());
    expect((first as Escaped).exitSteps, 1);
    expect(board.tap(a), isA<Escaped>());
    expect(board.isCleared, isTrue);
  });

  test('overlapping arrows are rejected', () {
    expect(
      () => PuzzleBoard(rows: 4, cols: 4, arrows: [
        a,
        arrow(5, [
          [0, 1],
          [1, 1],
        ]),
      ]),
      throwsArgumentError,
    );
  });

  test('mistakes cost lives and three mistakes lose the level', () {
    final game = GameController(level);
    for (var i = 0; i < 3; i++) {
      expect(game.tap(a), isA<Blocked>());
    }
    expect(game.lives, 0);
    expect(game.status, GameStatus.lost);
    expect(game.tap(b), isNull);

    game.revive();
    expect(game.lives, 1);
    expect(game.tap(b), isA<Escaped>());
    expect(game.tap(a), isA<Escaped>());
    expect(game.status, GameStatus.won);
  });

  test('hint always points at an arrow that can escape', () {
    final game = GameController(level);
    final hinted = game.hint();
    expect(hinted?.id, b.id);
    expect(game.hintArrowId, b.id);
  });

  test('arrows survive the level file format', () {
    final level = Level(number: 7, rows: 4, cols: 4, arrows: [a, b]);
    final back = LevelCodec.decodeLevel(LevelCodec.encodeLevel(level));
    expect(back.rows, 4);
    expect(back.cols, 4);
    expect([for (final x in back.arrows) x.cells], [a.cells, b.cells]);
    expect(LevelCodec.encodeArrow(b), '3,3:UUU');
  });

  test('endless levels after the bundled ones are solvable', () {
    for (var n = 301; n <= 310; n++) {
      final level = LevelGenerator.generate(n);
      expect(
        PuzzleBoard(rows: level.rows, cols: level.cols, arrows: level.arrows)
            .analyze()
            .solvable,
        isTrue,
        reason: 'level $n',
      );
    }
  });

  test('hard badge follows the level number', () {
    expect(LevelTier.forLevel(1), LevelTier.normal);
    expect(LevelTier.forLevel(99), LevelTier.normal);
    expect(LevelTier.forLevel(100), LevelTier.hard);
    expect(LevelTier.forLevel(250), LevelTier.superHard);
  });
}
