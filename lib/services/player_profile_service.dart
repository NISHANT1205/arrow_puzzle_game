import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class PlayerProfileException implements Exception {
  const PlayerProfileException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.username,
    required this.avatarId,
    required this.gameSlug,
    this.currentLevel = 1,
    this.gamesPlayed = 0,
  });
  factory PlayerProfile.fromJson(Map<String, dynamic> data) => PlayerProfile(
        id: data['id'] as String,
        username: data['username'] as String,
        avatarId: (data['avatarId'] as num).toInt(),
        gameSlug: data['gameSlug'] as String,
        currentLevel: (data['currentLevel'] as num?)?.toInt() ?? 1,
        gamesPlayed: (data['gamesPlayed'] as num?)?.toInt() ?? 0,
      );
  final String id;
  final String username;
  final int avatarId;
  final String gameSlug;
  final int currentLevel;
  final int gamesPlayed;
}

class PlayerProfileService {
  PlayerProfileService({
    http.Client? client,
    Future<SharedPreferences>? preferences,
    String baseUrl = ApiConfig.playerApiBaseUrl,
  })  : _client = client ?? http.Client(),
        _preferences = preferences ?? SharedPreferences.getInstance(),
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');
  static final instance = PlayerProfileService();
  static const tokenKey = 'player_profile_token_arrow-puzzle';
  static const idKey = 'player_profile_id_arrow-puzzle';
  static const cacheKey = 'player_profile_cache_arrow-puzzle';
  static const registrationKey = 'player_registration_secret_arrow-puzzle';
  Future<String>? _registrationId;

  Future<String> _getRegistrationId() => _registrationId ??= (() async {
        final prefs = await _preferences;
        final existing = prefs.getString(registrationKey);
        if (existing != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(existing)) {
          return existing;
        }
        final random = Random.secure();
        final id = List.generate(32,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
        await prefs.setString(registrationKey, id);
        return id;
      })();
  final profile = ValueNotifier<PlayerProfile?>(null);

  Future<void> loadCachedProfile() async {
    if (profile.value != null) return;
    final prefs = await _preferences;
    final cached = prefs.getString(cacheKey);
    if (cached == null || (prefs.getString(tokenKey) ?? '').isEmpty) return;
    try {
      final value =
          PlayerProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      if (value.gameSlug == ApiConfig.gameSlug && profile.value == null) {
        profile.value = value;
      }
    } catch (_) {
      await prefs.remove(cacheKey);
    }
  }

  final http.Client _client;
  final Future<SharedPreferences> _preferences;
  final String _baseUrl;
  Future<PlayerProfile>? _ensuring;

  Future<PlayerProfile> ensureProfile({
    String? preferredUsername,
    int avatarId = 0,
  }) {
    return _ensuring ??= _ensure(
      preferredUsername,
      avatarId,
    ).whenComplete(() => _ensuring = null);
  }

  Future<PlayerProfile> _ensure(String? preferredUsername, int avatarId) async {
    final prefs = await _preferences;
    final token = prefs.getString(tokenKey);
    if (token != null && token.isNotEmpty) {
      final response = await _client.get(
        Uri.parse(
          '$_baseUrl/players/me',
        ).replace(queryParameters: {'gameSlug': ApiConfig.gameSlug}),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return _decode(response, prefs);
      if (response.statusCode != 401 && response.statusCode != 403) {
        return _decode(response, prefs);
      }
      await prefs.remove(tokenKey);
      await prefs.remove(idKey);
      await prefs.remove(cacheKey);
      profile.value = null;
    }
    final name = preferredUsername?.trim() ?? '';
    if (RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(name)) {
      final response = await _post(
          'profile',
          {
            'username': name,
            'avatarId': avatarId,
          },
          null);
      if (response.statusCode != 409) return _decode(response, prefs);
    }
    final guest = await _decode(await _post('guest', {}, null), prefs);
    if (avatarId > 0 && avatarId < 18) {
      return _decode(
        await _post(
            'profile',
            {
              'username': guest.username,
              'avatarId': avatarId,
            },
            prefs.getString(tokenKey)),
        prefs,
      );
    }
    return guest;
  }

  Future<PlayerProfile> saveProfile({
    required String username,
    required int avatarId,
  }) async {
    username = username.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(username)) {
      throw const PlayerProfileException(
        'Use 4–20 letters, numbers, or underscores.',
      );
    }
    if (avatarId < 0 || avatarId >= 18) {
      throw const PlayerProfileException('Invalid avatar.');
    }
    await ensureProfile();
    final prefs = await _preferences;
    return _decode(
      await _post(
          'profile',
          {
            'username': username,
            'avatarId': avatarId,
          },
          prefs.getString(tokenKey)),
      prefs,
    );
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard({
    int limit = 100,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Invalid leaderboard pagination');
    }
    final uri = Uri.parse('$_baseUrl/players/leaderboard').replace(
      queryParameters: {
        'gameSlug': ApiConfig.gameSlug,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const PlayerProfileException('Could not load leaderboard.');
    }
    final rows = (jsonDecode(response.body)
        as Map<String, dynamic>)['leaderboard'] as List;
    return rows
        .map((row) => LeaderboardEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<http.Response> _post(
    String action,
    Map<String, Object> data,
    String? token,
  ) async {
    final registrationId = token == null ? await _getRegistrationId() : null;
    return _client
        .post(
          Uri.parse('$_baseUrl/players/$action'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            ...data,
            'gameSlug': ApiConfig.gameSlug,
            if (registrationId != null) 'registrationId': registrationId
          }),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<PlayerProfile> _decode(
    http.Response response,
    SharedPreferences prefs,
  ) async {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        await prefs.remove(tokenKey);
        await prefs.remove(idKey);
        await prefs.remove(cacheKey);
        profile.value = null;
      }
      throw PlayerProfileException(
        data?['error'] as String? ??
            'Could not connect to player service. Please try again.',
        statusCode: response.statusCode,
      );
    }
    final value = data?['player'];
    if (value is! Map<String, dynamic>) {
      throw const PlayerProfileException('Invalid player response.');
    }
    final decodedProfile = PlayerProfile.fromJson(value);
    if (decodedProfile.gameSlug != ApiConfig.gameSlug) {
      throw const PlayerProfileException('Player belongs to another game.');
    }
    final token = data?['accessToken'];
    if (token is String && token.isNotEmpty) {
      if (token != prefs.getString(tokenKey)) {
        await prefs.remove("arrow_backend_synced_v2");
      }
      await prefs.setString(tokenKey, token);
    }
    await prefs.setString(idKey, decodedProfile.id);
    await prefs.setString(cacheKey, jsonEncode(value));
    profile.value = decodedProfile;
    return decodedProfile;
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.avatarId,
    required this.currentLevel,
  });
  factory LeaderboardEntry.fromJson(Map<String, dynamic> data) =>
      LeaderboardEntry(
        rank: data['rank'] as int,
        username: data['username'] as String,
        avatarId: data['avatarId'] as int,
        currentLevel: (data['currentLevel'] as num?)?.toInt() ?? 1,
      );
  final int rank;
  final String username;
  final int avatarId;
  final int currentLevel;
}
