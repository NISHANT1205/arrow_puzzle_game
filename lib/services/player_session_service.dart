import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'player_profile_service.dart';

enum PlayerActivity { home, playing, paused, ad, background, ended }

/// Sends authenticated, idempotent session heartbeats without blocking UI.
/// Foreground and playing time come from a monotonic clock, not wall time.
class PlayerSessionService with WidgetsBindingObserver {
  PlayerSessionService({
    http.Client? client,
    PlayerProfileService? profiles,
    Future<SharedPreferences>? preferences,
    String baseUrl = ApiConfig.playerApiBaseUrl,
    this.heartbeatInterval = const Duration(seconds: 30),
    Duration Function()? elapsed,
  })  : _client = client ?? http.Client(),
        _profiles = profiles ?? PlayerProfileService.instance,
        _preferences = preferences ?? SharedPreferences.getInstance(),
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _elapsedOverride = elapsed;
  static final instance = PlayerSessionService();
  final http.Client _client;
  final PlayerProfileService _profiles;
  final Future<SharedPreferences> _preferences;
  final String _baseUrl;
  final Duration heartbeatInterval;
  final Duration Function()? _elapsedOverride;
  final _clock = Stopwatch();
  Timer? _timer;
  Timer? _retryTimer;
  int _retryFailures = 0;
  Future<void>? _starting;
  bool _started = false;
  bool _busy = false;
  Completer<void>? _idle;
  bool _dirty = false;
  bool _foreground = true;
  bool _focused = true;
  bool _ended = false;
  PlayerActivity _activity = PlayerActivity.home;
  String? _sessionId;
  String? _sessionToken;
  int _sequence = 1;
  int _lastCapture = 0;
  int _activeMs = 0;
  int _playingMs = 0;
  Map<String, Object>? _pending;
  Map<String, dynamic>? lastAcknowledgedSession;

  int get activeMilliseconds {
    _capture();
    return _activeMs;
  }

  int get playingMilliseconds {
    _capture();
    return _playingMs;
  }

  String? get sessionId => _sessionId;
  PlayerActivity get _state => _ended
      ? PlayerActivity.ended
      : !_foreground
          ? PlayerActivity.background
          : !_focused && _activity == PlayerActivity.playing
              ? PlayerActivity.paused
              : _activity;
  int get _elapsed =>
      (_elapsedOverride?.call() ?? _clock.elapsed).inMilliseconds;

  Future<void> start() =>
      _starting ??= _start().catchError((Object error, StackTrace stack) {
        _starting = null;
        if (!_ended) {
          _timer?.cancel();
          _timer = Timer(heartbeatInterval, () {
            unawaited(
              start().catchError((Object error) {
                debugPrint('Session startup retry failed: $error');
              }),
            );
          });
        }
        Error.throwWithStackTrace(error, stack);
      });
  Future<void> _start() async {
    if (_started) return;
    final prefs = await _preferences;
    if ((prefs.getString(PlayerProfileService.tokenKey) ?? '').isEmpty) {
      await _profiles.ensureProfile(
        preferredUsername: prefs.getString('profile_name'),
        avatarId: prefs.getInt('avatar_id') ?? 0,
      );
    }
    final random = Random.secure();
    _sessionId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _sessionToken = prefs.getString(PlayerProfileService.tokenKey);
    _clock.start();
    _lastCapture = _elapsed;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null) {
      _foreground = lifecycle != AppLifecycleState.paused &&
          lifecycle != AppLifecycleState.hidden &&
          lifecycle != AppLifecycleState.detached;
      _focused = lifecycle == AppLifecycleState.resumed;
    }
    _timer = Timer.periodic(heartbeatInterval, (_) {
      if (_foreground && !_ended) unawaited(flush());
    });
    await flush();
  }

  void _capture() {
    if (!_started) return;
    final now = _elapsed;
    final delta = max(0, now - _lastCapture);
    if (_foreground && !_ended) {
      _activeMs += delta;
      if (_focused && _activity == PlayerActivity.playing) _playingMs += delta;
    }
    _lastCapture = now;
  }

  void setActivity(PlayerActivity activity) {
    if (_ended || _activity == activity) return;
    _capture();
    _activity = activity;
    if (_started) unawaited(flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ended) return;
    _capture();
    _foreground = state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached;
    _focused = state == AppLifecycleState.resumed;
    if (_started) unawaited(flush());
  }

  void _scheduleRetry() {
    if (!_started || _ended || !_foreground) return;
    _retryTimer?.cancel();
    final delay = [3, 6, 12, 30][min(_retryFailures++, 3)];
    _retryTimer = Timer(Duration(seconds: delay), () => unawaited(flush()));
  }

  /// Retains the exact request on transport failure so a retry cannot double-count.
  Future<void> flush() async {
    if (!_started) return;
    _dirty = true;
    if (_busy) {
      await _idle?.future;
      return;
    }
    _busy = true;
    _idle = Completer<void>();
    try {
      final prefs = await _preferences;
      while (_dirty) {
        _dirty = false;
        _capture();
        _pending ??= {
          'gameSlug': ApiConfig.gameSlug,
          'sessionId': _sessionId!,
          'sequence': _sequence,
          'state': _state.name,
          'activeMilliseconds': _activeMs,
          'playingMilliseconds': _playingMs,
        };
        final token = prefs.getString(PlayerProfileService.tokenKey);
        if (token == null || token.isEmpty) {
          await _profiles.ensureProfile();
          _scheduleRetry();
          break;
        }
        if (_sessionToken != token) {
          _sessionId = List.generate(
              16,
              (_) => Random.secure()
                  .nextInt(256)
                  .toRadixString(16)
                  .padLeft(2, '0')).join();
          _sessionToken = token;
          _sequence = 1;
          _pending = null;
          _dirty = true;
          continue;
        }
        final response = await _client
            .post(
              Uri.parse('$_baseUrl/players/session'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(_pending),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint('Session heartbeat failed: HTTP ${response.statusCode}');
          if (response.statusCode == 401) {
            if (prefs.getString(PlayerProfileService.tokenKey) == token) {
              await prefs.remove(PlayerProfileService.tokenKey);
              await prefs.remove(PlayerProfileService.idKey);
            }
            await _profiles.ensureProfile();
            // A renewed player needs a new server session and sequence.
            _sessionId = List.generate(
                16,
                (_) => Random.secure()
                    .nextInt(256)
                    .toRadixString(16)
                    .padLeft(2, '0')).join();
            _sessionToken = prefs.getString(PlayerProfileService.tokenKey);
            _sequence = 1;
            _pending = null;
            _scheduleRetry();
          }
          if (response.statusCode >= 500 ||
              response.statusCode == 409 ||
              response.statusCode == 429) {
            _scheduleRetry();
          }
          break;
        }
        _retryTimer?.cancel();
        _retryFailures = 0;
        final received =
            (jsonDecode(response.body) as Map<String, dynamic>)['session'];
        if (received is Map<String, dynamic>) {
          lastAcknowledgedSession = Map.unmodifiable(received);
        }
        final stateSent = _pending!['state'];
        final activeSent = _pending!['activeMilliseconds'];
        final playingSent = _pending!['playingMilliseconds'];
        _sequence++;
        _pending = null;
        if (stateSent != _state.name ||
            activeSent != _activeMs ||
            playingSent != _playingMs) {
          _dirty = true;
        }
      }
    } catch (error) {
      debugPrint('Session heartbeat failed: $error');
      _scheduleRetry();
    } finally {
      _busy = false;
      _idle?.complete();
    }
  }

  Future<void> stop() async {
    _capture();
    _ended = true;
    _timer?.cancel();
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await flush();
  }
}
