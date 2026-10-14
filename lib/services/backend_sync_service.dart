import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'player_profile_service.dart';
import 'player_session_service.dart';

/// Durable snapshots and gameplay events; gameplay never waits for the network.
class BackendSyncService with WidgetsBindingObserver {
  BackendSyncService(
      {http.Client? client,
      PlayerProfileService? profiles,
      Future<SharedPreferences>? preferences,
      bool startSessions = true,
      String baseUrl = ApiConfig.playerApiBaseUrl})
      : _client = client ?? http.Client(),
        _profiles = profiles ?? PlayerProfileService.instance,
        _preferences = preferences ?? SharedPreferences.getInstance(),
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _startSessions = startSessions;

  static final instance = BackendSyncService();
  final http.Client _client;
  final PlayerProfileService _profiles;
  final Future<SharedPreferences> _preferences;
  final String _baseUrl;
  final bool _startSessions;
  bool _profileReady = false;
  bool _dirty = false;
  bool _enabled = false;
  Timer? _retry;
  Future<void>? _inFlight;
  Future<void> _writes = Future.value();
  static const queueKey = 'arrow_backend_events_v1';
  static const revisionKey = 'arrow_backend_revision_v1';
  static const syncedKey = 'arrow_backend_synced_v2';

  Future<void> start() async {
    _enabled = true;
    WidgetsBinding.instance.addObserver(this);
    final prefs = await _preferences;
    await prefs.setInt(
        "backend_best_level",
        max(prefs.getInt("backend_best_level") ?? 0,
            (prefs.getInt("current_level") ?? 1) - 1));
    await prefs.setInt(
        "backend_games_played",
        max(prefs.getInt("backend_games_played") ?? 0,
            prefs.getInt("levels_cleared") ?? 0));
    if (_startSessions) {
      unawaited(PlayerSessionService.instance.start().catchError((Object e) {
        debugPrint('Session startup will retry: $e');
      }));
    }
    await flush();
  }

  void changed() {
    if (!_enabled) return;
    _dirty = true;
    _writes = _writes.then((_) async {
      final prefs = await _preferences;
      await prefs.setInt(revisionKey, (prefs.getInt(revisionKey) ?? 0) + 1);
    });
    unawaited(flush());
  }

  void record(String type, Map<String, Object> data) {
    if (!_enabled) return;
    _dirty = true;
    _writes = _writes.then((_) async {
      final prefs = await _preferences;
      final rows = _events(prefs);
      final random = Random.secure();
      rows.add({
        'id': List.generate(16,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join(),
        'type': type,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        ...data,
      });
      await prefs.setString(queueKey, jsonEncode(rows));
      await prefs.setInt(revisionKey, (prefs.getInt(revisionKey) ?? 0) + 1);
    });
    unawaited(flush());
  }

  List<dynamic> _events(SharedPreferences prefs) =>
      jsonDecode(prefs.getString(queueKey) ?? '[]') as List<dynamic>;

  Future<void> flush() {
    if (!_enabled) return Future.value();
    return _inFlight ??= _drain().whenComplete(() {
      _inFlight = null;
      if (_enabled && _dirty && _retry == null) unawaited(flush());
    });
  }

  Future<void> _drain() async {
    try {
      if (!_profileReady) {
        await _profiles.ensureProfile();
        _profileReady = true;
      }
      final prefs = await _preferences;
      while (_enabled) {
        _dirty = false;
        await _writes;
        final revision = prefs.getInt(revisionKey) ?? 0;
        final rows = _events(prefs).take(100).toList();
        if (rows.isEmpty && prefs.getInt(syncedKey) == revision) break;
        final requestToken = prefs.getString(PlayerProfileService.tokenKey);
        final response = await _client
            .post(
              Uri.parse('$_baseUrl/arrow-puzzle/sync'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $requestToken'
              },
              body: jsonEncode({
                'gameSlug': ApiConfig.gameSlug,
                'revision': revision,
                'progress': {
                  'currentLevel': prefs.getInt('current_level') ?? 1,
                  'levelsCleared': prefs.getInt('levels_cleared') ?? 0,
                  'bestLevel': prefs.getInt('backend_best_level') ?? 0,
                  'gamesPlayed': prefs.getInt('backend_games_played') ?? 0,
                },
                'settings': {
                  'soundEnabled': prefs.getBool('sound_enabled') ?? true,
                  'hapticsEnabled': prefs.getBool('haptics_enabled') ?? true,
                  'darkMode': prefs.getBool('dark_mode') ?? false,
                },
                'events': rows,
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401) {
            _profileReady = false;
            if (prefs.getString(PlayerProfileService.tokenKey) ==
                requestToken) {
              await prefs.remove(PlayerProfileService.tokenKey);
              await prefs.remove(PlayerProfileService.idKey);
            }
          }
          throw StateError('Arrow sync HTTP ${response.statusCode}');
        }
        final ack = jsonDecode(response.body) as Map<String, dynamic>;
        if (ack['ok'] != true) {
          throw const FormatException('Missing sync acknowledgement');
        }
        // Serialize acknowledgement with new events so none are lost in flight.
        _writes = _writes.then((_) async {
          final ids = rows.map((e) => e['id']).toSet();
          await prefs.setString(
              queueKey,
              jsonEncode(_events(prefs)
                  .where((e) => !ids.contains(e['id']))
                  .toList()));
          await prefs.setInt(syncedKey, revision);
        });
        await _writes;
        _retry?.cancel();
        _retry = null;
      }
    } catch (error) {
      debugPrint('Backend sync queued for retry: $error');
      _retry?.cancel();
      if (_enabled) {
        _retry = Timer(const Duration(seconds: 30), () => unawaited(flush()));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      unawaited(flush());
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enabled = false;
    _retry?.cancel();
  }
}
