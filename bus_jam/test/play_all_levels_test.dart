import 'dart:io';

import 'package:bus_jam/app_state.dart';
import 'package:bus_jam/screens/game_screen.dart';
import 'package:bus_jam/services/level_repository.dart';
import 'package:bus_jam/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays every level through the real game screen: taps each vehicle of the
/// level's solution on the lot, exactly as a player would, and expects the
/// win dialog at the end.
void main() {
  final repo = LevelRepository(
    LevelRepository.parse(File('assets/levels.json').readAsStringSync()),
  );

  testWidgets('every level can be won by tapping vehicles in the game UI', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'current_user': '__guest__'});
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final state = await AppState.create(levels: repo);

    for (var n = 1; n <= repo.count; n++) {
      await t.pumpWidget(
        AppScope(
          key: ValueKey(n),
          state: state,
          child: MaterialApp(home: GameScreen(number: n)),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      for (final m in repo[n].solution) {
        final car = find.byKey(Key('veh-$m'));
        expect(car, findsOneWidget, reason: 'level $n vehicle $m');
        await t.tap(car, warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 50));
      }
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.textContaining('COMPLETE!').evaluate().isNotEmpty ||
            find.text('ALL LEVELS DONE!').evaluate().isNotEmpty,
        isTrue,
        reason: 'level $n did not show the win dialog',
      );
      expect(state.progress.stars[n], 3, reason: 'level $n');
    }
    expect(state.progress.stars.length, repo.count);
  });
}
