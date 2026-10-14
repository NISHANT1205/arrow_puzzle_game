import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arrow_puzzle/services/player_session_service.dart';
import 'package:arrow_puzzle/services/player_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'player_profile_token_arrow-puzzle': 'test-token',
    }),
  );
  test(
    'session separates foreground, gameplay, pauses, ads and background time',
    () async {
      var elapsed = Duration.zero;
      final sent = <Map<String, dynamic>>[];
      final service = PlayerSessionService(
        elapsed: () => elapsed,
        client: MockClient((request) async {
          expect(request.url.path, '/api/players/session');
          expect(jsonDecode(request.body)['gameSlug'], 'arrow-puzzle');
          expect(request.headers['Authorization'], 'Bearer test-token');
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"session":{}}', 200);
        }),
      );
      await service.start();
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await service.flush();
      elapsed = const Duration(seconds: 10);
      service.setActivity(PlayerActivity.playing);
      await service.flush();
      expect(sent.last['activeMilliseconds'], 10000);
      expect(sent.last['playingMilliseconds'], 0);
      elapsed = const Duration(seconds: 40);
      service.setActivity(PlayerActivity.paused);
      await service.flush();
      expect(sent.last['playingMilliseconds'], 30000);
      elapsed = const Duration(seconds: 45);
      service.setActivity(PlayerActivity.ad);
      await service.flush();
      elapsed = const Duration(seconds: 50);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      await service.flush();
      expect(sent.last['state'], 'background');
      expect(sent.last['activeMilliseconds'], 50000);
      elapsed = const Duration(seconds: 110);
      service.setActivity(PlayerActivity.playing);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await service.flush();
      expect(sent.last['activeMilliseconds'], 50000);
      elapsed = const Duration(seconds: 120);
      await service.stop();
      expect(sent.last['state'], 'ended');
      expect(sent.last['activeMilliseconds'], 60000);
      expect(sent.last['playingMilliseconds'], 40000);
      expect(sent.map((event) => event['sessionId']).toSet(), {
        service.sessionId,
      });
      expect(
        sent.map((event) => event['sequence']).toList(),
        List.generate(sent.length, (i) => i + 1),
      );
    },
  );
  test(
    'failed heartbeat retries identical sequence and counters before latest state',
    () async {
      var elapsed = Duration.zero;
      var fail = true;
      final sent = <Map<String, dynamic>>[];
      final service = PlayerSessionService(
        elapsed: () => elapsed,
        client: MockClient((request) async {
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', fail ? 503 : 200);
        }),
      );
      await service.start();
      fail = false;
      elapsed = const Duration(seconds: 10);
      service.setActivity(PlayerActivity.playing);
      await service.flush();
      expect(sent[1], sent[0]);
      expect(sent.last['sequence'], 2);
      expect(sent.last['state'], 'playing');
      expect(sent.last['activeMilliseconds'], 10000);
      await service.stop();
    },
  );
  test('state changes serialize while heartbeat is in flight', () async {
    final first = Completer<http.Response>();
    final sent = <Map<String, dynamic>>[];
    var inFlight = 0;
    var peak = 0;
    final service = PlayerSessionService(
      client: MockClient((request) async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        final response =
            sent.length == 1 ? await first.future : http.Response('{}', 200);
        inFlight--;
        return response;
      }),
    );
    final starting = service.start();
    await Future<void>.delayed(Duration.zero);
    service.setActivity(PlayerActivity.playing);
    first.complete(http.Response('{}', 200));
    await starting;
    expect(peak, 1);
    expect(sent.last['state'], 'playing');
    await service.stop();
  });
  testWidgets(
    'transport retry preserves the original request then sends missed counters',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      var elapsed = Duration.zero;
      final service = PlayerSessionService(
        elapsed: () => elapsed,
        client: MockClient((request) async {
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (sent.length == 1) throw StateError('Temporary network failure');
          return http.Response('{"session":{}}', 200);
        }),
      );
      await service.start();
      elapsed = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(sent.length, 3);
      expect(sent[1], sent[0]);
      expect(sent[2]["sequence"], 2);
      expect(sent[2]["activeMilliseconds"], 3000);
      expect(sent[2]["playingMilliseconds"], 0);
      await service.stop();
    },
  );
  test('a refreshed player token starts a new session at sequence one',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final sent = <Map<String, dynamic>>[];
    var rejected = false;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/guest')) {
        expect(jsonDecode(r.body)['registrationId'],
            matches(RegExp(r'^[a-f0-9]{64}$')));
        return http.Response(
            jsonEncode({
              'player': {
                'id': 'renewed',
                'username': 'guest54321',
                'avatarId': 0,
                'gameSlug': 'arrow-puzzle'
              },
              'accessToken': 'renewed-token'
            }),
            201);
      }
      sent.add(jsonDecode(r.body) as Map<String, dynamic>);
      if (!rejected) {
        rejected = true;
        return http.Response('{}', 401);
      }
      expect(r.headers['Authorization'], 'Bearer renewed-token');
      return http.Response('{"session":{}}', 200);
    });
    final service = PlayerSessionService(
        client: client,
        preferences: Future.value(prefs),
        profiles: PlayerProfileService(
            client: client, preferences: Future.value(prefs)));
    await service.start();
    await service.flush();
    expect(sent, hasLength(2));
    expect(sent[0]['sessionId'], isNot(sent[1]['sessionId']));
    expect(sent[1]['sequence'], 1);
    await service.stop();
    client.close();
  });
}
