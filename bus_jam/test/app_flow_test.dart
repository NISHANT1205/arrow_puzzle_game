import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/app_state.dart';
import 'package:bus_jam/engine/game_state.dart';
import 'package:bus_jam/main.dart';
import 'package:bus_jam/services/level_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final repo = LevelRepository(
    LevelRepository.parse(File('assets/levels.json').readAsStringSync()),
  );

  Future<AppState> boot(
    WidgetTester t, [
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final state = await AppState.create(levels: repo);
    await t.pumpWidget(ScrewJamApp(state: state));
    await settle(t, 2200);
    return state;
  }

  testWidgets('sign up, win level 1 by tapping vehicles, unlock level 2', (
    t,
  ) async {
    final state = await boot(t);
    expect(find.byKey(const Key('submit')), findsOneWidget);

    // Switch to sign up and create an account.
    await t.tap(find.text('Sign Up'));
    await settle(t, 300);
    await t.enterText(find.byKey(const Key('username')), 'nishant');
    await t.enterText(find.byKey(const Key('password')), 'secret1');
    await t.enterText(find.byKey(const Key('confirm')), 'secret1');
    await t.tap(find.byKey(const Key('submit')));
    await settle(t);
    expect(find.byKey(const Key('display-name')), findsOneWidget);
    expect(find.text('nishant'), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);

    await t.tap(find.byKey(const Key('play')));
    await settle(t, 800);
    expect(find.text('Level 1'), findsOneWidget);

    final level = repo[1];
    for (final m in level.solution) {
      await t.tap(find.byKey(Key('veh-$m')));
      await settle(t, 500);
    }
    await settle(t);
    expect(find.text('LEVEL COMPLETE!'), findsOneWidget);
    expect(state.progress.stars[1], 3);
    expect(state.progress.unlocked, 2);

    await t.tap(find.byKey(const Key('next-level')));
    await settle(t, 800);
    expect(find.text('Level 2'), findsOneWidget);
  });

  testWidgets('wrong password is rejected, then login works', (t) async {
    await boot(t);
    await t.tap(find.text('Sign Up'));
    await settle(t, 300);
    await t.enterText(find.byKey(const Key('username')), 'player_1');
    await t.enterText(find.byKey(const Key('password')), 'hunter22');
    await t.enterText(find.byKey(const Key('confirm')), 'hunter22');
    await t.tap(find.byKey(const Key('submit')));
    await settle(t);

    await t.tap(find.byKey(const Key('profile')));
    await settle(t, 800);
    await t.scrollUntilVisible(
      find.byKey(const Key('logout')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const Key('logout')));
    await settle(t);

    await t.enterText(find.byKey(const Key('username')), 'player_1');
    await t.enterText(find.byKey(const Key('password')), 'wrongpass');
    await t.tap(find.byKey(const Key('submit')));
    await settle(t, 500);
    expect(find.byKey(const Key('auth-error')), findsOneWidget);

    await t.enterText(find.byKey(const Key('password')), 'hunter22');
    await t.tap(find.byKey(const Key('submit')));
    await settle(t);
    expect(find.text('player_1'), findsOneWidget);
  });

  testWidgets('sign up validation and guest mode', (t) async {
    await boot(t);
    await t.tap(find.text('Sign Up'));
    await settle(t, 300);
    await t.enterText(find.byKey(const Key('username')), 'ab');
    await t.enterText(find.byKey(const Key('password')), '123');
    await t.enterText(find.byKey(const Key('confirm')), '999');
    await t.tap(find.byKey(const Key('submit')));
    await settle(t, 300);
    expect(find.text('At least 3 characters'), findsOneWidget);
    expect(find.text('At least 6 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);

    await t.tap(find.byKey(const Key('guest')));
    await settle(t);
    expect(find.text('Guest'), findsOneWidget);
  });

  testWidgets('locked levels cannot be opened', (t) async {
    await boot(t, {'current_user': '__guest__'});
    await t.tap(find.byKey(const Key('levels')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('level-2')));
    await settle(t, 300);
    expect(find.text('Level 2'), findsNothing);
    expect(find.text('Beat level 1 to unlock'), findsOneWidget);
  });

  testWidgets('full bays show the fail dialog and undo recovers', (t) async {
    // Find a losing sequence for level 50 with a seeded random player.
    final level = repo[50];
    List<int>? losing;
    for (var seed = 0; losing == null; seed++) {
      final rng = Random(seed);
      final g = GameState.initial(level);
      final moves = <int>[];
      while (g.legalMoves().isNotEmpty) {
        final m = g.legalMoves()[rng.nextInt(g.legalMoves().length)];
        g.tap(m);
        moves.add(m);
      }
      if (g.isStuck) losing = moves;
    }

    await boot(t, {
      'current_user': '__guest__',
      'progress:__guest__': '{"unlocked":50,"coins":0,"stars":{}}',
    });
    await t.tap(find.byKey(const Key('play')));
    await settle(t, 800);
    expect(find.text('Level 50'), findsOneWidget);

    for (final m in losing) {
      await t.tap(find.byKey(Key('veh-$m')));
      await settle(t, 400);
    }
    await settle(t);
    expect(find.text('OUT OF SPACE!'), findsOneWidget);

    await t.tap(find.byKey(const Key('fail-undo')));
    await settle(t);
    expect(find.text('OUT OF SPACE!'), findsNothing);
  });

  testWidgets('tapping a blocked vehicle does not move it', (t) async {
    await boot(t, {'current_user': '__guest__'});
    await t.tap(find.byKey(const Key('play')));
    await settle(t, 800);
    final level = repo[1];
    final g = GameState.initial(level);
    final blocked = [
      for (var i = 0; i < level.vehicles.length; i++)
        if (g.blocker(i) != null) i,
    ];
    if (blocked.isEmpty) return;
    await t.tap(find.byKey(Key('veh-${blocked.first}')));
    await settle(t, 600);
    expect(find.byKey(Key('veh-${blocked.first}')), findsOneWidget);
    expect(find.text('${level.queue.length}'), findsOneWidget);
  });
}
