import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/engine/arrow_board.dart';
import 'package:arrow_puzzle/models/level.dart';
import 'package:arrow_puzzle/state/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testLevel = Level(
    id: 1,
    pack: 'Test',
    gridSize: 3,
    arrows: [
      Arrow(row: 1, col: 0, direction: ArrowDirection.right),
      Arrow(row: 1, col: 2, direction: ArrowDirection.up),
    ],
    solutionOrder: const [
      [1, 2],
      [1, 0],
    ],
  );

  test('blocked taps preserve the board and successful taps can be undone', () {
    final notifier = GameNotifier()..startGame(testLevel);
    expect(notifier.tapArrow(1, 0), isFalse);
    expect(notifier.state!.blockedTapCount, 1);
    expect(notifier.state!.board.arrows, hasLength(2));

    expect(notifier.tapArrow(1, 2), isTrue);
    expect(notifier.state!.board.arrows, hasLength(1));
    notifier.undo();
    expect(notifier.state!.board.arrows, hasLength(2));
  });

  test('live hint is currently tappable', () {
    final notifier = GameNotifier()..startGame(testLevel);
    final hint = notifier.getHint();
    expect(hint, isNotNull);
    expect(notifier.state!.board.isPathClear(hint!), isTrue);
    expect(notifier.state!.hintedArrow, hint);
  });

  test('all bundled levels replay their validated solution', () {
    final raw = jsonDecode(File('assets/data/levels.json').readAsStringSync())
        as List<dynamic>;
    expect(raw, hasLength(200));
    for (final entry in raw) {
      final level = Level.fromJson(entry as Map<String, dynamic>);
      final board = ArrowBoard(
        gridSize: level.gridSize,
        initialArrows: level.arrows,
      );
      for (final position in level.solutionOrder) {
        expect(
          board.tapArrow(position[0], position[1]),
          isTrue,
          reason: 'Level ${level.id} failed at $position',
        );
      }
      expect(board.isCleared(), isTrue, reason: 'Level ${level.id} not clear');
    }
  });

  test('diagonal JSON directions retain their direction', () {
    expect(ArrowDirection.fromString('upLeft'), ArrowDirection.upLeft);
    expect(ArrowDirection.fromString('downRight'), ArrowDirection.downRight);
  });
}
