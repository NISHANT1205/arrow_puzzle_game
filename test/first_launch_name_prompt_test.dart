import 'dart:convert';
import 'package:arrow_puzzle/services/player_profile_service.dart';
import 'package:arrow_puzzle/theme/app_theme.dart';
import 'package:arrow_puzzle/widgets/first_launch_name_prompt.dart';
import 'package:arrow_puzzle/widgets/player_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> open(WidgetTester tester, PlayerProfileService profiles,
      SharedPreferences prefs,
      {Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(brightness),
        home: FirstLaunchNamePrompt(
            profiles: profiles,
            preferences: Future.value(prefs),
            child: const Scaffold(body: Text('Home')))));
    await tester.pumpAndSettle();
  }

  Map<String, Object> player(String name) => {
        'id': 'one',
        'username': name,
        'avatarId': 4,
        'gameSlug': 'arrow-puzzle',
        'currentLevel': 1,
        'gamesPlayed': 0
      };

  testWidgets(
      'first launch edits guest username, preserves avatar and only prompts once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <http.Request>[];
    var name = 'guest12345';
    final client = MockClient((r) async {
      calls.add(r);
      if (r.url.path.endsWith('/profile')) {
        expect(r.headers['Authorization'], 'Bearer token');
        final body = jsonDecode(r.body);
        expect(body['avatarId'], 4);
        expect(body['gameSlug'], 'arrow-puzzle');
        name = body['username'];
      }
      return http.Response(
          jsonEncode({
            'player': player(name),
            if (r.url.path.endsWith('/guest')) 'accessToken': 'token'
          }),
          200);
    });
    final service =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await open(tester, service, prefs);
    expect(find.text('Name'), findsOneWidget);
    expect(find.byType(PlayerAvatar), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'guest12345');
    await tester.enterText(find.byType(TextFormField), 'Puzzle_Pro');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(service.profile.value!.username, 'Puzzle_Pro');
    expect(find.byType(AlertDialog), findsNothing);
    expect(prefs.getBool(FirstLaunchNamePrompt.completedKey), true);
    expect(calls.where((r) => r.url.path.endsWith('/guest')), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await open(tester, service, prefs, brightness: Brightness.dark);
    expect(find.byType(AlertDialog), findsNothing);
    client.close();
  });

  testWidgets('invalid and taken usernames keep popup open until corrected',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var taken = true;
    var updates = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/profile')) {
        updates++;
        if (taken) return http.Response('{"error":"Username taken"}', 409);
      }
      return http.Response(
          jsonEncode({'player': player('guest12345'), 'accessToken': 'token'}),
          200);
    });
    final service =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await open(tester, service, prefs, brightness: Brightness.dark);
    await tester.enterText(find.byType(TextFormField), 'ab');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(updates, 0);
    await tester.enterText(find.byType(TextFormField), 'Puzzle_Pro');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
        find.text('That username is taken. Try another one.'), findsOneWidget);
    expect(prefs.getBool(FirstLaunchNamePrompt.completedKey), true);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Puzzle_Pro');
    taken = false;
    await tester.enterText(find.byType(TextFormField), 'Puzzle_Pro2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    client.close();
  });

  testWidgets('offline first launch still shows popup and allows Not now',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client =
        MockClient((r) async => throw http.ClientException('offline'));
    final service =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await open(tester, service, prefs);
    expect(find.text('Name'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Could not save your name. Check your connection and try again.'),
        findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(prefs.getBool(FirstLaunchNamePrompt.completedKey), true);
    client.close();
  });
  testWidgets(
      'closing on first popup and repeated cold launches never show it again',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client =
        MockClient((r) async => throw http.ClientException('offline'));
    await open(
        tester,
        PlayerProfileService(client: client, preferences: Future.value(prefs)),
        prefs);
    expect(find.text('Name'), findsOneWidget);
    expect(prefs.getBool(FirstLaunchNamePrompt.completedKey), true);
    // Dispose the entire app while the welcome is open, without Save or Not now.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    client.close();
    for (var launch = 0; launch < 5; launch++) {
      SharedPreferences.setMockInitialValues(
          {FirstLaunchNamePrompt.completedKey: true});
      final restored = await SharedPreferences.getInstance();
      var requests = 0;
      final offline = MockClient((r) async {
        requests++;
        throw http.ClientException('offline');
      });
      await open(
          tester,
          PlayerProfileService(
              client: offline, preferences: Future.value(restored)),
          restored);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'relaunch $launch');
      expect(requests, 0,
          reason: 'checking the first-launch flag needs no network');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      offline.close();
    }
  });
}
