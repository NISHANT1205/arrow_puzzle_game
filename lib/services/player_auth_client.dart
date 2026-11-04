import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Renews a rejected player token once, without changing the player or request.
class PlayerAuthClient extends http.BaseClient {
  PlayerAuthClient(this.inner,
      {required this.gameSlug,
      required this.tokenKey,
      Future<SharedPreferences>? preferences})
      : preferences = preferences ?? SharedPreferences.getInstance();
  final http.Client inner;
  final String gameSlug;
  final String tokenKey;
  final Future<SharedPreferences> preferences;
  String get refreshKey => '${tokenKey}_refresh_v1';
  static final Map<String, Future<String>> _renewing = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest original) async {
    final prefs = await preferences;
    final bytes = await original.finalize().toBytes();
    var url = original.url;
    var body = bytes;
    final bearer = original.headers['authorization'];
    final needsCredential = prefs.getString(refreshKey) == null;
    if (needsCredential && url.path.endsWith('/players/me')) {
      url = url.replace(queryParameters: {
        ...url.queryParameters,
        'gameSlug': gameSlug,
        'refreshCredentials': '1'
      });
    }
    if (needsCredential &&
        original.method == 'POST' &&
        (url.path.endsWith('/players/guest') ||
            url.path.endsWith('/players/profile') && bearer == null)) {
      final data =
          bytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(bytes));
      if (data is Map<String, dynamic>) {
        body = utf8.encode(jsonEncode({...data, 'refreshCredentials': true}));
      }
    }
    Future<http.Response> sendOnce([String? token]) async {
      final request = http.Request(original.method, url)
        ..headers.addAll(original.headers)
        ..followRedirects = original.followRedirects
        ..maxRedirects = original.maxRedirects
        ..persistentConnection = original.persistentConnection;
      if (token != null) request.headers['authorization'] = 'Bearer $token';
      request.bodyBytes = body;
      request.headers.remove('content-length');
      return http.Response.fromStream(await inner.send(request));
    }

    final initialToken = bearer != null && prefs.getString(refreshKey) != null
        ? prefs.getString(tokenKey)
        : null;
    final sentBearer = initialToken == null ? bearer : 'Bearer $initialToken';
    var response = await sendOnce(initialToken);
    if (response.statusCode == 401 &&
        bearer != null &&
        !url.path.endsWith('/players/refresh')) {
      final refresh = prefs.getString(refreshKey);
      if (refresh != null) {
        final current = prefs.getString(tokenKey);
        try {
          final token = current != null && sentBearer != 'Bearer $current'
              ? current
              : await _renew(url, prefs, refresh);
          response = await sendOnce(token);
        } catch (_) {
          // Existing callers must keep the account/outbox on refresh failures.
          response = http.Response(
              '{"error":"Player token renewal unavailable; retry"}', 503,
              headers: {'content-type': 'application/json'});
        }
        if (response.statusCode == 401) {
          response = http.Response(
              '{"error":"Player token renewal rejected; retry"}', 503,
              headers: {'content-type': 'application/json'});
        }
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map &&
            data['refreshToken'] is String &&
            data['player'] is Map &&
            data['player']['gameSlug'] == gameSlug) {
          await prefs.setString(refreshKey, data['refreshToken'] as String);
        }
      } on FormatException {/* Non-JSON responses remain for the caller. */}
    }
    return http.StreamedResponse(
        Stream.value(response.bodyBytes), response.statusCode,
        contentLength: response.bodyBytes.length,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: original,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection);
  }

  Future<String> _renew(
      Uri url, SharedPreferences prefs, String refresh) async {
    final key = '${url.origin}:$gameSlug:$refresh';
    final pending = _renewing[key];
    if (pending != null) return pending;
    late final Future<String> future;
    future = (() async {
      final api = url.path.indexOf('/api/');
      if (api < 0) {
        throw StateError('Invalid player API URL');
      }
      final endpoint = url.replace(
          path: '${url.path.substring(0, api)}/api/players/refresh', query: '');
      final response = await inner
          .post(endpoint,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'gameSlug': gameSlug, 'refreshToken': refresh}))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError('Player token renewal failed');
      }
      final data = jsonDecode(response.body);
      if (data is! Map ||
          data['accessToken'] is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(data['accessToken']) ||
          data['player'] is! Map ||
          data['player']['gameSlug'] != gameSlug) {
        throw StateError('Invalid token renewal response');
      }
      final token = data['accessToken'] as String;
      if (!await prefs.setString(tokenKey, token)) {
        throw StateError('Token could not be saved');
      }
      return token;
    })()
        .whenComplete(() {
      if (identical(_renewing[key], future)) {
        _renewing.remove(key);
      }
    });
    _renewing[key] = future;
    return future;
  }

  @override
  void close() => inner.close();
}
