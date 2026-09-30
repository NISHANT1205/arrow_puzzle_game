import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/arrow_path.dart';
import 'package:arrow_puzzle/models/level.dart';
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

  test('generated levels are deterministic', () {
    final one = LevelGenerator.generate(42).toJson();
    final two = LevelGenerator.generate(42).toJson();
    expect(one, two);
  });

  test('the first 300 generated levels are all solvable', () {
    for (var n = 1; n <= 300; n++) {
      final level = LevelGenerator.generate(n);
      expect(level.arrows, isNotEmpty, reason: 'level $n is empty');
      final board = PuzzleBoard(
        rows: level.rows,
        cols: level.cols,
        arrows: level.arrows,
      );
      expect(board.solve(), isNotNull, reason: 'level $n is stuck');
      // Replaying the greedy solution through the game rules clears it.
      final game = GameController(level);
      while (game.status == GameStatus.playing) {
        final free = game.board.freeArrows();
        expect(free, isNotEmpty, reason: 'level $n got stuck while playing');
        expect(game.tap(free.first), isA<Escaped>());
      }
      expect(game.status, GameStatus.won);
      expect(game.mistakes, 0);
    }
  });
}
