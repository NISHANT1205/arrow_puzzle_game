import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arrow_puzzle/services/player_auth_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const slug = 'test-game';
  const key = 'test-token';
  final fresh = 'n' * 43;
  setUp(() => SharedPreferences.setMockInitialValues(
      {key: 'old-token', '${key}_refresh_v1': 'r' * 43}));
  PlayerAuthClient client(http.Client inner) =>
      PlayerAuthClient(inner, gameSlug: slug, tokenKey: key);
  final uri = Uri.parse('https://game.test/api/players/session');
  test('401 renews once and retries the exact session payload immediately',
      () async {
    final bodies = <String>[];
    var refreshes = 0;
    final api = client(MockClient((request) async {
      if (request.url.path.endsWith('/refresh')) {
        refreshes++;
        expect(jsonDecode(request.body)['gameSlug'], slug);
        return http.Response(
            jsonEncode({
              'accessToken': fresh,
              'player': {'id': 'same-player', 'gameSlug': slug}
            }),
            200);
      }
      bodies.add(request.body);
      return http.Response('{}',
          request.headers['Authorization'] == 'Bearer $fresh' ? 200 : 401);
    }));
    final response = await api.post(uri,
        headers: {'Authorization': 'Bearer old-token'},
        body:
            '{"sequence":2,"sessionId":"same-session","activeMilliseconds":3000}');
    expect(response.statusCode, 200);
    expect(bodies.length, 2);
    expect(bodies[1], bodies[0]);
    expect(refreshes, 1);
    expect((await SharedPreferences.getInstance()).getString(key), fresh);
    api.close();
  });
  test('refresh rejection preserves credentials and becomes a retryable error',
      () async {
    var calls = 0;
    final api = client(MockClient((request) async {
      calls++;
      return http.Response('{}', 401);
    }));
    expect(
        (await api.post(uri,
                headers: {'Authorization': 'Bearer old-token'}, body: '{}'))
            .statusCode,
        503);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), 'old-token');
    expect(prefs.getString('${key}_refresh_v1'), 'r' * 43);
    expect(calls, 2);
    api.close();
  });
  test('repeated 401 after renewal is bounded and retains the player',
      () async {
    var calls = 0;
    final api = client(MockClient((request) async {
      calls++;
      if (request.url.path.endsWith('/refresh')) {
        return http.Response(
            jsonEncode({
              'accessToken': fresh,
              'player': {'id': 'same-player', 'gameSlug': slug}
            }),
            200);
      }
      return http.Response('{}', 401);
    }));
    expect(
        (await api.post(uri,
                headers: {'Authorization': 'Bearer old-token'}, body: '{}'))
            .statusCode,
        503);
    expect(calls, 3);
    api.close();
  });
  test('two service clients share concurrent renewal', () async {
    final release = Completer<void>();
    var refreshes = 0;
    final inner = MockClient((request) async {
      if (request.url.path.endsWith('/refresh')) {
        refreshes++;
        await release.future;
        return http.Response(
            jsonEncode({
              'accessToken': fresh,
              'player': {'id': 'same-player', 'gameSlug': slug}
            }),
            200);
      }
      return http.Response('{}',
          request.headers['Authorization'] == 'Bearer $fresh' ? 200 : 401);
    });
    final first = client(inner);
    final second = client(inner);
    final requests = [
      first.post(uri,
          headers: {'Authorization': 'Bearer old-token'}, body: '{}'),
      second.post(uri,
          headers: {'Authorization': 'Bearer old-token'}, body: '{}')
    ];
    await Future<void>.delayed(const Duration(milliseconds: 20));
    release.complete();
    expect((await Future.wait(requests)).map((r) => r.statusCode), [200, 200]);
    expect(refreshes, 1);
    first.close();
  });
  test('provisions and stores a refresh credential during profile restoration',
      () async {
    SharedPreferences.setMockInitialValues({key: 'old-token'});
    final api = client(MockClient((request) async {
      expect(request.url.queryParameters['refreshCredentials'], '1');
      expect(request.url.queryParameters['gameSlug'], slug);
      return http.Response(
          jsonEncode({
            'refreshToken': 'r' * 43,
            'player': {'id': 'same-player', 'gameSlug': slug}
          }),
          200);
    }));
    await api.get(Uri.parse('https://game.test/api/players/me'),
        headers: {'Authorization': 'Bearer old-token'});
    expect(
        (await SharedPreferences.getInstance()).getString('${key}_refresh_v1'),
        'r' * 43);
    api.close();
  });
  test('another game response cannot replace this game credentials', () async {
    final api = client(MockClient((request) async {
      if (request.url.path.endsWith('/refresh')) {
        return http.Response(
            jsonEncode({
              'accessToken': fresh,
              'player': {'gameSlug': 'other-game'}
            }),
            200);
      }
      return http.Response('{}', 401);
    }));
    expect(
        (await api.post(uri,
                headers: {'Authorization': 'Bearer old-token'}, body: '{}'))
            .statusCode,
        503);
    expect((await SharedPreferences.getInstance()).getString(key), 'old-token');
    api.close();
  });
  test(
      'a cached service token uses the already renewed token without another 401',
      () async {
    SharedPreferences.setMockInitialValues(
        {key: fresh, '${key}_refresh_v1': 'r' * 43});
    var calls = 0;
    final api = client(MockClient((request) async {
      calls++;
      expect(request.url.path, '/api/players/session');
      expect(request.headers['Authorization'], 'Bearer $fresh');
      return http.Response('{}', 200);
    }));
    expect(
        (await api.post(uri,
                headers: {'Authorization': 'Bearer old-token'}, body: '{}'))
            .statusCode,
        200);
    expect(calls, 1);
    api.close();
  });
}
