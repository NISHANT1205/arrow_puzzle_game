import 'dart:io';
import 'dart:math';

import 'package:bus_jam/engine/game_state.dart';
import 'package:bus_jam/engine/solver.dart';
import 'package:bus_jam/services/level_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
        expect(l.vehicles, isNotEmpty);
        expect(l.slots, greaterThan(0));
        // Vehicles stay inside the lot and never overlap.
        final cells = <(int, int)>{};
        for (final v in l.vehicles) {
          for (final (x, y) in v.cells) {
            expect(x >= 0 && y >= 0 && x < l.cols && y < l.rows, isTrue);
            expect(cells.add((x, y)), isTrue, reason: 'overlap at $x,$y');
          }
        }
        // Exactly one passenger per seat, colour by colour.
        final seats = <int, int>{};
        for (final v in l.vehicles) {
          seats[v.color] = (seats[v.color] ?? 0) + v.seats;
        }
        final pax = <int, int>{};
        for (final c in l.queue) {
          pax[c] = (pax[c] ?? 0) + 1;
        }
        expect(pax, seats);
      });
    }
  });

  group('stored solution wins every level', () {
    for (final l in levels) {
      test('level ${l.number}', () {
        final g = GameState.initial(l);
        for (final m in l.solution) {
          expect(g.tap(m), TapResult.parked, reason: 'vehicle $m');
        }
        expect(g.isWon, isTrue);
        expect(g.passengersLeft, 0);
        expect(g.bays.every((b) => b == null), isTrue);
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
          expect(g.tap(m), TapResult.parked);
        }
        expect(g.isWon, isTrue);
      });
    }
  });

  group('random play never soft-locks', () {
    // Whatever the player taps, the game ends in a clear win or a detected
    // "no moves" state; the lot itself can never jam with bays free.
    for (final l in levels) {
      test('level ${l.number}', () {
        final rng = Random(l.number);
        for (var t = 0; t < 30; t++) {
          final g = GameState.initial(l);
          var steps = 0;
          while (true) {
            final inLot = g.loc.where((x) => x == VehicleLoc.lot).length;
            if (inLot > 0 && g.hasFreeBay) {
              expect(
                g.legalMoves(),
                isNotEmpty,
                reason: 'lot jammed with a free bay',
              );
            }
            final moves = g.legalMoves();
            if (moves.isEmpty) break;
            expect(g.tap(moves[rng.nextInt(moves.length)]), TapResult.parked);
            expect(g.loc.where((x) => x == VehicleLoc.lot).length, inLot - 1);
            expect(++steps, lessThanOrEqualTo(l.vehicles.length));
          }
          expect(g.isWon || g.isStuck, isTrue);
          if (g.isWon) {
            expect(g.passengersLeft, 0);
          } else {
            expect(g.hasFreeBay, isFalse, reason: 'stuck only with full bays');
          }
        }
      });
    }
  });
}
