import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String username;
  final String displayName;
  final int avatar;
  final bool isGuest;

  const UserProfile({
    required this.username,
    required this.displayName,
    required this.avatar,
    this.isGuest = false,
  });
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Offline accounts stored on the device. Passwords are salted and hashed
/// with SHA-256; nothing leaves the phone.
class AuthService {
  static const _usersKey = 'users';
  static const _currentKey = 'current_user';
  static const guestUsername = '__guest__';
  static const avatarCount = 8;

  final SharedPreferences prefs;
  AuthService(this.prefs);

  Map<String, dynamic> _users() {
    final raw = prefs.getString(_usersKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<void> _saveUsers(Map<String, dynamic> users) =>
      prefs.setString(_usersKey, jsonEncode(users));

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String? validateUsername(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 3) return 'At least 3 characters';
    if (s.length > 16) return 'At most 16 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(s)) {
      return 'Letters, numbers and _ only';
    }
    return null;
  }

  static String? validatePassword(String? v) {
    if ((v ?? '').length < 6) return 'At least 6 characters';
    return null;
  }

  UserProfile? get currentUser {
    final name = prefs.getString(_currentKey);
    if (name == null) return null;
    if (name == guestUsername) return guest;
    final u = _users()[name.toLowerCase()];
    if (u == null) return null;
    return _profile(name.toLowerCase(), u as Map);
  }

  static const guest = UserProfile(
    username: guestUsername,
    displayName: 'Guest',
    avatar: 0,
    isGuest: true,
  );

  UserProfile _profile(String key, Map u) => UserProfile(
    username: key,
    displayName: u['display'] as String,
    avatar: u['avatar'] as int,
  );

  Future<UserProfile> signUp(
    String username,
    String password, {
    int avatar = 0,
  }) async {
    final err = validateUsername(username) ?? validatePassword(password);
    if (err != null) throw AuthException(err);
    final users = _users();
    final key = username.trim().toLowerCase();
    if (users.containsKey(key)) {
      throw AuthException('That username is already taken');
    }
    final rnd = Random.secure();
    final salt = base64Url.encode(List.generate(16, (_) => rnd.nextInt(256)));
    users[key] = {
      'display': username.trim(),
      'salt': salt,
      'hash': _hash(salt, password),
      'avatar': avatar % avatarCount,
      'created': DateTime.now().toIso8601String(),
    };
    await _saveUsers(users);
    await prefs.setString(_currentKey, key);
    return _profile(key, users[key] as Map);
  }

  Future<UserProfile> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    final u = _users()[key] as Map?;
    if (u == null || _hash(u['salt'] as String, password) != u['hash']) {
      throw AuthException('Wrong username or password');
    }
    await prefs.setString(_currentKey, key);
    return _profile(key, u);
  }

  Future<UserProfile> continueAsGuest() async {
    await prefs.setString(_currentKey, guestUsername);
    return guest;
  }

  Future<void> setAvatar(String username, int avatar) async {
    final users = _users();
    final u = users[username] as Map?;
    if (u == null) return;
    u['avatar'] = avatar % avatarCount;
    await _saveUsers(users);
  }

  Future<void> logout() => prefs.remove(_currentKey);
}
