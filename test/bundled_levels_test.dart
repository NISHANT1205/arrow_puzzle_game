// Checks the curated schedule, solvability, and gameplay of all 225 levels.

import 'dart:io';
import 'dart:math';

import 'package:arrow_puzzle/engine/board_shape.dart';
import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/level.dart';
import 'package:arrow_puzzle/models/level_codec.dart';
import 'package:arrow_puzzle/services/level_repository.dart';
import 'package:arrow_puzzle/state/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = LevelRepository.parse(
    File(LevelRepository.assetPath).readAsStringSync(),
  );
  final levels = [for (final l in raw) LevelCodec.decodeLevel(l)];

  test('there are 225 levels, numbered in order', () {
    expect(levels.length, 225);
    for (var i = 0; i < levels.length; i++) {
      expect(levels[i].number, i + 1);
    }
  });

  test('maps from level 76 contain at least 50 percent more dots', () {
    for (var i = 0; i < levels.length; i++) {
      if (i < 75) {
        expect(raw[i].containsKey('originalDots'), isFalse);
      } else {
        final original = raw[i]['originalDots'] as int;
        expect(levels[i].shape.cells.length,
            greaterThanOrEqualTo((original * 1.5).ceil()),
            reason: 'level ${i + 1}');
        // Regenerated boards use the enlarged area for actual puzzle paths.
        expect(levels[i].arrows.length, greaterThan(10));
      }
    }
  });

  test('every level is solvable and matches its recorded stats', () {
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      final stats = _board(level).analyze();
      expect(stats.solvable, isTrue, reason: 'level ${level.number}');
      final recorded = raw[i]['s'] as Map<String, dynamic>;
      expect(stats.arrows, recorded['arrows']);
      expect(stats.layers, recorded['layers']);
      expect(stats.initialFree, recorded['free']);
    }
  });

  test('each slot retains its hardest 75 with peaks every fifth level', () {
    final sources = <int>{};
    for (var slot = 0; slot < 3; slot++) {
      final regular = <double>[];
      final hardest = <double>[];
      for (var i = slot * 75; i < (slot + 1) * 75; i++) {
        final source = raw[i]['sourceLevel'] as int;
        expect(sources.add(source), isTrue);
        expect(source, inInclusiveRange(slot * 100 + 26, (slot + 1) * 100));
        final score = _board(levels[i]).analyze().score;
        (levels[i].number % 5 == 0 ? hardest : regular).add(score);
      }
      expect(hardest.length, 15);
      expect(regular.length, 60);
      expect(hardest.reduce(min), greaterThan(regular.reduce(max)));
      expect(hardest, orderedEquals([...hardest]..sort()));
      expect(regular, orderedEquals([...regular]..sort()));
    }
  });

  test('selected cubes preserve their original face coverage', () {
    for (final l in levels.where((l) => l.isCube)) {
      final shape = l.shape as CubeShape;
      // From level 150 cubes have arrows on all six sides.
      expect(shape.allSides, (raw[l.number - 1]['sourceLevel'] as int) >= 150,
          reason: 'level ${l.number}');
      if (shape.allSides) {
        final perFace = List.filled(6, 0);
        for (final a in l.arrows) {
          perFace[shape.faceOf(a.head)]++;
        }
        expect(
          perFace.every((k) => k >= 2),
          isTrue,
          reason: 'level ${l.number}: arrows per side $perFace',
        );
      }
      // Some arrows start out blocked by an arrow on another face.
      final board = PuzzleBoard.forLevel(l);
      final crossFace = l.arrows.where((a) {
        final r = board.evaluate(a);
        return r is Blocked && shape.faceOf(r.hitCell) != shape.faceOf(a.head);
      }).length;
      expect(crossFace, greaterThanOrEqualTo(2), reason: 'level ${l.number}');
    }
  });

  test('a perfect player wins every level with no mistakes', () {
    for (final level in levels) {
      final game = GameController(level);
      while (game.status == GameStatus.playing) {
        final free = game.board.freeArrows();
        expect(free, isNotEmpty, reason: 'level ${level.number} got stuck');
        expect(game.tap(free.first), isA<Escaped>());
      }
      expect(game.status, GameStatus.won, reason: 'level ${level.number}');
      expect(game.mistakes, 0);
    }
  });

  test('random players always reach a win or a loss, never a dead end', () {
    final rng = Random(2024);
    for (final level in levels) {
      for (var run = 0; run < 5; run++) {
        final game = GameController(level);
        var taps = 0;
        var revived = false;
        while (true) {
          if (game.status == GameStatus.lost && !revived) {
            // Keep going after a loss once, like the Continue button.
            revived = true;
            game.revive();
          }
          if (game.status != GameStatus.playing) break;
          // While the game is on there is always a safe move.
          expect(
            game.board.freeArrows(),
            isNotEmpty,
            reason: 'level ${level.number} stuck after $taps taps',
          );
          final arrows = game.board.arrows.toList();
          final result = game.tap(arrows[rng.nextInt(arrows.length)]);
          expect(result, isNotNull);
          taps++;
          // Every tap removes an arrow or costs a life, so games are short.
          expect(taps, lessThanOrEqualTo(level.arrows.length + 4));
        }
        expect(
          game.status,
          anyOf(GameStatus.won, GameStatus.lost),
          reason: 'level ${level.number}',
        );
        expect(game.stuck, isFalse);
        if (game.status == GameStatus.won) {
          expect(game.remainingArrows, 0);
        } else {
          expect(game.lives, 0);
          expect(game.remainingArrows, greaterThan(0));
        }
      }
    }
  });

  test('the hint is always a safe move', () {
    final rng = Random(7);
    for (final level in levels) {
      final game = GameController(level);
      while (game.status == GameStatus.playing) {
        final hint = game.hint();
        expect(hint, isNotNull, reason: 'no hint on level ${level.number}');
        expect(game.board.canEscape(hint!), isTrue);
        // Sometimes follow the hint, sometimes another free arrow.
        final free = game.board.freeArrows();
        final pick = rng.nextBool() ? hint : free[rng.nextInt(free.length)];
        expect(game.tap(pick), isA<Escaped>());
      }
      expect(game.status, GameStatus.won);
    }
  });
}

PuzzleBoard _board(Level level) => PuzzleBoard.forLevel(level);
