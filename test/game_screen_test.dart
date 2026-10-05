// Plays the real game screen with taps, the way a player would: every
// bundled level in a row via the "Next Level" button, plus losing, retrying
// and continuing. Catches levels where the game neither wins nor loses.

import 'dart:io';

import 'package:arrow_puzzle/engine/puzzle_board.dart';
import 'package:arrow_puzzle/models/arrow_path.dart';
import 'package:arrow_puzzle/screens/game_screen.dart';
import 'package:arrow_puzzle/services/level_repository.dart';
import 'package:arrow_puzzle/services/local_storage_service.dart';
import 'package:arrow_puzzle/state/game_controller.dart';
import 'package:arrow_puzzle/widgets/arrow_board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<Map<String, dynamic>> bundled = LevelRepository.parse(
  File(LevelRepository.assetPath).readAsStringSync(),
);
final int bundledCount = bundled.length;

/// Number of the first bundled cube level (with arrows on all sides, or on
/// the three front faces).
int _firstCube({required bool allSides}) {
  for (final l in bundled) {
    final shape = l['shape'] as Map<String, dynamic>?;
    if (shape != null && (shape['all'] == true) == allSides) {
      return l['n'] as int;
    }
  }
  throw StateError('no cube level');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService().init();
  });

  testWidgets('every bundled level can be won by tapping, one after another',
      (tester) async {
    await _openLevel(tester, 1);
    for (var n = 1; n <= bundledCount; n++) {
      final game = _game(tester);
      expect(game.level.number, n);
      await _solveByTapping(tester);
      expect(game.status, GameStatus.won, reason: 'level $n');
      await _waitForDialog(tester, 'Level Complete!', n);
      await tester.tap(find.text('Next Level'));
      await _waitForBoard(tester, n + 1);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('three crashes lose, and Continue / Try Again recover',
      (tester) async {
    await _openLevel(tester, 40);
    for (var i = 0; i < GameController.maxLives; i++) {
      await _tapArrow(tester, _blockedArrow(tester));
      await tester.pump(const Duration(milliseconds: 1600));
    }
    expect(_game(tester).status, GameStatus.lost);
    await _waitForDialog(tester, 'Out of lives', 40);

    // Continue with one heart, crash again: lost for good this time.
    await tester.tap(find.textContaining('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_game(tester).lives, 1);
    await _tapArrow(tester, _blockedArrow(tester));
    await tester.pump(const Duration(milliseconds: 1600));
    await _waitForDialog(tester, 'Out of lives', 40);
    expect(find.textContaining('Continue'), findsNothing);

    // Try Again restarts the level, which can then be won.
    await tester.tap(find.text('Try Again'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_game(tester).lives, GameController.maxLives);
    expect(_game(tester).remainingArrows, _game(tester).totalArrows);
    await _solveByTapping(tester);
    await _waitForDialog(tester, 'Level Complete!', 40);
  });

  testWidgets('a cube turns when dragged', (tester) async {
    await _openLevel(tester, _firstCube(allSides: true));
    final before = _board(tester).view;
    await tester.drag(find.byType(ArrowBoardView), const Offset(-120, 60));
    await tester.pump(const Duration(milliseconds: 100));
    final after = _board(tester).view;
    expect(after.yaw, isNot(closeTo(before.yaw, .01)));
    expect(after.pitch, isNot(closeTo(before.pitch, .01)));
  });

  testWidgets('a hint on the back of the cube turns it into view',
      (tester) async {
    await _openLevel(tester, _firstCube(allSides: true));
    final game = _game(tester);
    // Clear arrows until the hint lands on a hidden side.
    while (true) {
      final hint = game.hint();
      expect(hint, isNotNull);
      if (!_board(tester).isShown(hint!.head)) {
        // The turn starts on the next frame and takes under half a second.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(_board(tester).isShown(hint.head), isTrue);
        return;
      }
      await _tapArrow(tester, hint);
      await tester.pump(const Duration(milliseconds: 50));
      if (game.status != GameStatus.playing) fail('no hidden hint found');
    }
  });

  testWidgets('winning with the last heart still wins', (tester) async {
    await _openLevel(tester, 120);
    for (var i = 0; i < GameController.maxLives - 1; i++) {
      await _tapArrow(tester, _blockedArrow(tester));
      await tester.pump(const Duration(milliseconds: 1600));
    }
    expect(_game(tester).lives, 1);
    await _solveByTapping(tester);
    await _waitForDialog(tester, 'Level Complete!', 120);
  });
}

Future<void> _openLevel(WidgetTester tester, int number) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: GameScreen(levelNumber: number)),
    ),
  );
  await _waitForBoard(tester, number);
}

GameController _game(WidgetTester tester) =>
    tester.widget<ArrowBoardView>(find.byType(ArrowBoardView)).controller;

ArrowPath _blockedArrow(WidgetTester tester) => _game(tester)
    .board
    .arrows
    .firstWhere((a) => _game(tester).board.evaluate(a) is Blocked);

ArrowBoardViewState _board(WidgetTester tester) =>
    tester.state<ArrowBoardViewState>(find.byType(ArrowBoardView));

/// Taps the middle of [arrow]'s head cell on screen, first turning the cube
/// when the arrow is on a side facing away (as a player would).
Future<void> _tapArrow(WidgetTester tester, ArrowPath arrow) async {
  if (!_board(tester).isShown(arrow.head)) {
    _board(tester).showNow(arrow.head);
    await tester.pump();
    expect(_board(tester).isShown(arrow.head), isTrue);
  }
  final origin = tester.getTopLeft(find.byType(ArrowBoardView));
  await tester.tapAt(origin + _board(tester).positionOf(arrow.head));
  await tester.pump(const Duration(milliseconds: 16));
}

/// Clears the board by tapping free arrows; each tap must remove exactly
/// one arrow.
Future<void> _solveByTapping(WidgetTester tester) async {
  final game = _game(tester);
  while (game.status == GameStatus.playing) {
    final free = game.board.freeArrows();
    expect(free, isNotEmpty, reason: 'level ${game.level.number} is stuck');
    final before = game.remainingArrows;
    await _tapArrow(tester, free.first);
    expect(
      game.remainingArrows,
      before - 1,
      reason: 'tap on ${free.first} in level ${game.level.number} missed',
    );
  }
}

Future<void> _waitForDialog(WidgetTester tester, String text, int level) async {
  for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text(text), findsOneWidget, reason: 'level $level: no "$text"');
  // Let the dialog finish its pop-in animation before tapping its buttons.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _waitForBoard(WidgetTester tester, int level) async {
  for (var i = 0; i < 300; i++) {
    // Real time for work off the test clock (asset loading, background
    // level generation).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final boards = find.byType(ArrowBoardView).evaluate();
    // The previous result dialog must be fully gone too.
    final dialogGone = find.text('Level Complete!').evaluate().isEmpty &&
        find.text('Out of lives').evaluate().isEmpty;
    if (dialogGone &&
        boards.isNotEmpty &&
        (boards.first.widget as ArrowBoardView).controller.level.number ==
            level) {
      return;
    }
  }
  fail('level $level never appeared');
}
