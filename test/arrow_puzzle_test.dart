import 'package:arrow_puzzle/engine/board_shape.dart';
import 'package:arrow_puzzle/engine/level_generator.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/arrow_path.dart';
import 'package:arrow_puzzle/models/level.dart';
import 'package:arrow_puzzle/models/level_codec.dart';
import 'package:arrow_puzzle/state/game_controller.dart';
import 'package:arrow_puzzle/widgets/arrow_board_view.dart';
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

  group('3D cube', () {
    const cube = CubeShape(3);
    // Rows 0-2 are the top face, 3-5 the left face, 6-8 the right face.

    test('lanes run over the cube edges onto the next face', () {
      // Top face, moving right off its edge: down the right face.
      expect(
        cube.ahead(const Cell(0, 2), Dir.right),
        (const Cell(6, 2), Dir.down),
      );
      // Top face, moving down off its edge: down the left face.
      expect(
        cube.ahead(const Cell(2, 0), Dir.down),
        (const Cell(3, 0), Dir.down),
      );
      // Left face, moving right: onto the right face, still going right.
      expect(
        cube.ahead(const Cell(3, 2), Dir.right),
        (const Cell(6, 0), Dir.right),
      );
      // Right face, moving up: onto the top face, going left.
      expect(
        cube.ahead(const Cell(6, 0), Dir.up),
        (const Cell(2, 2), Dir.left),
      );
      // Off the cube's outline: gone.
      expect(cube.ahead(const Cell(5, 1), Dir.down), isNull);
      expect(cube.ahead(const Cell(0, 0), Dir.up), isNull);
    });

    test('an arrow on one face is blocked by an arrow on another', () {
      // On the top face pointing right, towards the right face.
      final top = arrow(0, [
        [1, 0],
        [1, 1],
      ]);
      // On the right face, in the column the top arrow's lane runs down
      // after going over the edge. It points down, off the cube.
      final side = arrow(1, [
        [7, 1],
        [8, 1],
      ]);
      final board = PuzzleBoard(
        rows: 9,
        cols: 3,
        arrows: [top, side],
        shape: cube,
      );
      final result = board.evaluate(top);
      expect(result, isA<Blocked>());
      expect((result as Blocked).blocker.id, side.id);
      // Once the side arrow has left, the top arrow's lane is clear.
      expect(board.tap(side), isA<Escaped>());
      expect(board.tap(top), isA<Escaped>());
    });

    test('bodies stay on one face', () {
      expect(
        () => PuzzleBoard(
          rows: 9,
          cols: 3,
          shape: cube,
          arrows: [
            arrow(0, [
              [2, 0],
              [3, 0],
            ]),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('cube boards are always solvable and survive the level file', () {
      for (final n in [4, 6, 9]) {
        final config = LevelGenerator.cubeConfig(n, .9);
        for (var seed = 0; seed < 10; seed++) {
          final arrows = LevelGenerator.build(config, seed);
          final level = LevelGenerator.toLevel(1, config, arrows);
          expect(PuzzleBoard.forLevel(level).analyze().solvable, isTrue);
          final back = LevelCodec.decodeLevel(LevelCodec.encodeLevel(level));
          expect(back.isCube, isTrue);
          expect((back.shape as CubeShape).n, n);
        }
      }
    });

    test('the slide animation follows the lane over the cube edge', () {
      // Top face arrow pointing right: its lane goes over onto the right
      // face and down it.
      final top = arrow(0, [
        [1, 0],
        [1, 1],
      ]);
      final track = buildTrack(cube, top, 6);
      // Points are half a cell apart all the way, bends included.
      for (var i = 1; i < track.length; i++) {
        expect((track[i].p - track[i - 1].p).length, closeTo(.5, 1e-9));
      }
      // It passes through the centres of the cells the lane visits, on the
      // right faces.
      for (final cell in const [Cell(1, 2), Cell(6, 1), Cell(7, 1)]) {
        final at = track.where((t) => t.p.same(cube.center3(cell)));
        expect(at, isNotEmpty, reason: '$cell not on the track');
        expect(at.first.face, cube.faceOf(cell));
      }
      // Once off the cube the track is in the air.
      expect(track.last.face, -1);
    });
  });

  group('cube with arrows on all sides', () {
    const cube = CubeShape(3, allSides: true);
    // Faces: 0 top, 1 left, 2 right, 3 bottom, 4 back-left, 5 back-right.

    test('has six faces that meet edge to edge', () {
      expect(cube.faceCount, 6);
      expect(cube.rows, 18);
      // Every cell centre lies on the surface of the 3 x 3 x 3 cube.
      for (final c in cube.cells) {
        final p = cube.center3(c);
        final onSurface = [p.x, p.y, p.z].any((v) => v == 0 || v == 3);
        expect(onSurface, isTrue, reason: '$c at $p');
      }
      // Walking off any face lands on the neighbouring face, and walking
      // back returns to the same cell.
      for (final c in cube.cells) {
        for (final d in Dir.values) {
          final next = cube.ahead(c, d);
          expect(next, isNotNull, reason: '$c $d');
          final back = cube.ahead(next!.$1, next.$2.opposite);
          expect(back?.$1, c, reason: '$c $d and back');
        }
      }
    });

    test('a lane goes over one edge, then flies off at the next', () {
      // Left face, bottom row, heading down: over the edge onto the bottom
      // face, across it, and off at its far edge.
      final lane = cube.laneSteps(const Cell(5, 1), Dir.down).toList();
      final faces = lane.map((s) => cube.faceOf(s.$1)).toSet();
      expect(faces, {CubeShape.bottom});
      expect(lane.length, 3);
      // On the three-face cube the same move leaves the cube at once.
      expect(const CubeShape(3).lane(const Cell(5, 1), Dir.down), isEmpty);
    });

    test('only faces turned to the camera are visible', () {
      const front = CubeView.iso;
      expect(
        [for (var f = 0; f < 6; f++) cube.faceVisible(f, front)],
        [true, true, true, false, false, false],
      );
      // From behind and below, the back and bottom faces show instead.
      final back = CubeView(front.yaw + 3.14159, -front.pitch);
      expect(
        [for (var f = 0; f < 6; f++) cube.faceVisible(f, back)],
        [false, false, false, true, true, true],
      );
    });

    test('all-sides cube boards are solvable and use every side', () {
      for (final n in [5, 8]) {
        final config = LevelGenerator.cubeConfig(n, .9, allSides: true);
        for (var seed = 0; seed < 6; seed++) {
          final arrows = LevelGenerator.build(config, seed);
          final level = LevelGenerator.toLevel(1, config, arrows);
          expect(PuzzleBoard.forLevel(level).analyze().solvable, isTrue);
          final shape = level.shape as CubeShape;
          final faces = {for (final a in arrows) shape.faceOf(a.head)};
          expect(faces.length, greaterThanOrEqualTo(5), reason: 'n=$n $faces');
          final back = LevelCodec.decodeLevel(LevelCodec.encodeLevel(level));
          expect((back.shape as CubeShape).allSides, isTrue);
        }
      }
    });
  });
}
