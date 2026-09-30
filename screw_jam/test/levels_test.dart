import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:screw_jam/engine/game_state.dart';
import 'package:screw_jam/engine/level.dart';
import 'package:screw_jam/engine/solver.dart';
import 'package:screw_jam/services/level_repository.dart';

void main() {
  final levels = LevelRepository.parse(
    File('assets/levels.json').readAsStringSync(),
  );

  test('ships at least 200 levels numbered 1..N', () {
    expect(levels.length, greaterThanOrEqualTo(200));
    for (var i = 0; i < levels.length; i++) {
      expect(levels[i].number, i + 1);
    }
  });

  group('every level is well formed', () {
    for (final l in levels) {
      test('level ${l.number}', () {
        expect(l.boxes, isNotEmpty);
        expect(l.screws.length, l.boxes.length * LevelDef.boxCapacity);
        // Each colour has exactly enough screws to fill its boxes.
        final screwsPerColor = <int, int>{};
        for (final s in l.screws) {
          screwsPerColor[s.color] = (screwsPerColor[s.color] ?? 0) + 1;
        }
        final boxesPerColor = <int, int>{};
        for (final b in l.boxes) {
          boxesPerColor[b] = (boxesPerColor[b] ?? 0) + 1;
        }
        expect(screwsPerColor.keys.toSet(), boxesPerColor.keys.toSet());
        for (final c in boxesPerColor.keys) {
          expect(screwsPerColor[c], boxesPerColor[c]! * 3, reason: 'colour $c');
        }
        // Screws sit inside their plate, inside the board, one per cell.
        final cells = <int>{};
        for (final s in l.screws) {
          expect(s.plate, inInclusiveRange(0, l.plates.length - 1));
          expect(l.plates[s.plate].covers(s.x, s.y), isTrue);
          expect(s.x, inInclusiveRange(0, l.cols - 1));
          expect(s.y, inInclusiveRange(0, l.rows - 1));
          expect(
            cells.add(s.y * l.cols + s.x),
            isTrue,
            reason: 'two screws share a cell',
          );
        }
        for (final p in l.plates) {
          expect(p.x >= 0 && p.y >= 0, isTrue);
          expect(p.x + p.w <= l.cols && p.y + p.h <= l.rows, isTrue);
        }
        // Every plate is held by at least one screw.
        for (var p = 0; p < l.plates.length; p++) {
          expect(
            l.screws.any((s) => s.plate == p),
            isTrue,
            reason: 'plate $p has no screws',
          );
        }
      });
    }
  });

  group('stored solution wins every level', () {
    for (final l in levels) {
      test('level ${l.number}', () {
        final g = GameState.initial(l);
        for (final m in l.solution) {
          final r = g.tap(m);
          expect(
            r == TapResult.toBox || r == TapResult.toBuffer,
            isTrue,
            reason: 'move $m returned $r',
          );
        }
        expect(g.isWon, isTrue);
        expect(g.buffer, isEmpty);
        expect(g.plateAlive.every((a) => !a), isTrue);
      });
    }
  });

  group('independent solver solves every level from scratch', () {
    for (final l in levels) {
      test('level ${l.number}', () {
        final path = Solver(nodeLimit: 200000).solve(GameState.initial(l));
        expect(path, isNotNull);
        final g = GameState.initial(l);
        for (final m in path!) {
          g.tap(m);
        }
        expect(g.isWon, isTrue);
      });
    }
  });

  group('random play never soft-locks', () {
    // Whatever the player does, the game must always end in a clear win or
    // a detected "no moves" state, never hang with moves that do nothing.
    for (final l in levels) {
      test('level ${l.number}', () {
        final rng = Random(l.number);
        for (var t = 0; t < 30; t++) {
          final g = GameState.initial(l);
          var steps = 0;
          while (true) {
            final moves = g.legalMoves();
            if (moves.isEmpty) break;
            final before = g.screwLoc
                .where((x) => x == ScrewLocation.board)
                .length;
            final r = g.tap(moves[rng.nextInt(moves.length)]);
            expect(r == TapResult.toBox || r == TapResult.toBuffer, isTrue);
            final after = g.screwLoc
                .where((x) => x == ScrewLocation.board)
                .length;
            expect(after, before - 1);
            expect(g.buffer.length, lessThanOrEqualTo(g.bufferCapacity));
            expect(++steps, lessThanOrEqualTo(l.screws.length));
          }
          expect(g.isWon || g.isStuck, isTrue);
          if (g.isWon) {
            expect(g.buffer, isEmpty);
            expect(g.screwLoc.every((x) => x == ScrewLocation.box), isTrue);
          }
        }
      });
    }
  });
}
