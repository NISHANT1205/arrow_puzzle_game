import 'dart:async';
import 'dart:convert';
import 'package:arrow_puzzle/services/backend_sync_service.dart';
import 'package:arrow_puzzle/services/player_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object> player() => {
      'id': 'test-player',
      'username': 'guest12345',
      'avatarId': 0,
      'gameSlug': 'arrow-puzzle',
      'currentLevel': 1,
      'gamesPlayed': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates game-scoped guest, restores token and authenticates updates',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <http.Request>[];
    var remotePlayer = player();
    final client = MockClient((r) async {
      calls.add(r);
      if (r.url.path.endsWith('/guest')) {
        expect(jsonDecode(r.body)['gameSlug'], 'arrow-puzzle');
        return http.Response(
            jsonEncode({'player': player(), 'accessToken': 'token'}), 201);
      }
      expect(r.headers['Authorization'], 'Bearer token');
      if (r.url.path.endsWith('/profile')) {
        final update = jsonDecode(r.body) as Map<String, dynamic>;
        remotePlayer = {
          ...remotePlayer,
          'username': update['username'] as String,
          'avatarId': update['avatarId'] as int
        };
      }
      return http.Response(jsonEncode({'player': remotePlayer}), 200);
    });
    final profiles =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await profiles.ensureProfile();
    await profiles.ensureProfile();
    await profiles.saveProfile(username: 'New_Name', avatarId: 17);
    expect(profiles.profile.value?.username, 'New_Name');
    final offline =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await offline.loadCachedProfile();
    expect(offline.profile.value?.username, 'New_Name');
    expect(offline.profile.value?.avatarId, 17);
    expect(calls.where((r) => r.url.path.endsWith('/guest')), hasLength(1));
    expect(calls.last.method, 'POST');
    expect(jsonDecode(calls.last.body),
        {'username': 'New_Name', 'avatarId': 17, 'gameSlug': 'arrow-puzzle'});
    client.close();
  });

  test('expired token creates a new guest; foreign-game responses are rejected',
      () async {
    SharedPreferences.setMockInitialValues(
        {PlayerProfileService.tokenKey: 'expired'});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient((r) async => r.method == 'GET'
        ? http.Response('{"error":"expired"}', 401)
        : http.Response(
            jsonEncode({
              'player': {...player(), 'gameSlug': 'fruit-splash'},
              'accessToken': 'wrong'
            }),
            201));
    final profiles =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await expectLater(
        profiles.ensureProfile(), throwsA(isA<PlayerProfileException>()));
    expect(prefs.getString(PlayerProfileService.tokenKey), isNull);
    client.close();
  });

  test('offline queue survives restart; retries keep event IDs and reset data',
      () async {
    SharedPreferences.setMockInitialValues({
      PlayerProfileService.tokenKey: 'token',
      'current_level': 1,
      'levels_cleared': 0,
      'backend_best_level': 12,
      'backend_games_played': 18,
      'dark_mode': true,
    });
    final prefs = await SharedPreferences.getInstance();
    var online = false;
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(jsonEncode({'player': player()}), 200);
      }
      expect(r.headers['Authorization'], 'Bearer token');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      sent.add(body);
      return online
          ? http.Response('{"ok":true}', 200)
          : http.Response('{}', 503);
    });
    BackendSyncService service() => BackendSyncService(
          client: client,
          preferences: Future.value(prefs),
          startSessions: false,
          profiles: PlayerProfileService(
              client: client, preferences: Future.value(prefs)),
        );
    final first = service();
    await first.start();
    first.record('reset', {});
    await first.flush();
    // Flush again if record arrived during the previous request.
    await first.flush();
    final queued =
        jsonDecode(prefs.getString(BackendSyncService.queueKey)!) as List;
    expect(queued, hasLength(1));
    first.dispose();
    online = true;
    final restarted = service();
    await restarted.start();
    expect(sent.last['events'][0]['id'], queued[0]['id']);
    expect(sent.last['progress']['currentLevel'], 1);
    expect(sent.last['progress']['bestLevel'], 12);
    expect(sent.last['settings']['darkMode'], true);
    expect(jsonDecode(prefs.getString(BackendSyncService.queueKey)!), isEmpty);
    expect(sent.last["progress"]["gamesPlayed"], 18);
    expect(sent.every((body) => !body.containsKey("score")), isTrue);
    restarted.dispose();
    client.close();
  });
  test('events written during upload survive acknowledgement of an older batch',
      () async {
    SharedPreferences.setMockInitialValues(
        {PlayerProfileService.tokenKey: 'token'});
    final prefs = await SharedPreferences.getInstance();
    final started = Completer<void>();
    final release = Completer<void>();
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(jsonEncode({'player': player()}), 200);
      }
      sent.add(jsonDecode(r.body) as Map<String, dynamic>);
      if (sent.length == 1) {
        started.complete();
        await release.future;
      }
      return http.Response('{"ok":true}', 200);
    });
    final service = BackendSyncService(
      client: client,
      preferences: Future.value(prefs),
      profiles: PlayerProfileService(
          client: client, preferences: Future.value(prefs)),
      startSessions: false,
    );
    final launch = service.start();
    await started.future;
    service.record('reset', {});
    service.record('start', {'level': 1, 'attemptId': 'test'});
    release.complete();
    await launch;
    await service.flush();
    expect(sent.expand((b) => b['events'] as List).map((e) => e['type']),
        ['reset', 'start']);
    expect(jsonDecode(prefs.getString(BackendSyncService.queueKey)!), isEmpty);
    service.dispose();
    client.close();
  });
  test(
      'lost guest response retries with the same registration secret after restart',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final registrations = <String>[];
    final client = MockClient((r) async {
      registrations.add(jsonDecode(r.body)['registrationId'] as String);
      if (registrations.length == 1) {
        throw http.ClientException('response lost');
      }
      return http.Response(
          jsonEncode({'player': player(), 'accessToken': 'token'}), 200);
    });
    final first =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await expectLater(
        first.ensureProfile(), throwsA(isA<http.ClientException>()));
    expect(prefs.getString(PlayerProfileService.tokenKey), isNull);
    final restarted =
        PlayerProfileService(client: client, preferences: Future.value(prefs));
    await restarted.ensureProfile();
    expect(registrations, hasLength(2));
    expect(registrations[1], registrations[0]);
    expect(registrations[0], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(prefs.getString(PlayerProfileService.tokenKey), 'token');
    client.close();
  });
  test('late unauthorized response does not erase a freshly renewed token',
      () async {
    SharedPreferences.setMockInitialValues(
        {PlayerProfileService.tokenKey: 'old'});
    final prefs = await SharedPreferences.getInstance();
    var reject = true;
    final client = MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(jsonEncode({'player': player()}), 200);
      }
      if (reject) {
        reject = false;
        await prefs.setString(PlayerProfileService.tokenKey, 'fresh');
        return http.Response('{}', 401);
      }
      expect(r.headers['Authorization'], 'Bearer fresh');
      return http.Response('{"ok":true}', 200);
    });
    final service = BackendSyncService(
        client: client,
        startSessions: false,
        profiles: PlayerProfileService(
            client: client, preferences: Future.value(prefs)),
        preferences: Future.value(prefs));
    await service.start();
    expect(prefs.getString(PlayerProfileService.tokenKey), 'fresh');
    await service.flush();
    expect(prefs.getString(PlayerProfileService.tokenKey), 'fresh');
    service.dispose();
    client.close();
  });
}
