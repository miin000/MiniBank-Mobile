import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';

class AuthStorage {
  static const _tokenKey = 'accessToken';
  static const _userKey = 'authUser';
  static const _deviceIdKey = 'deviceId';

  Future<void> save({required String token, required AuthUser user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<AuthUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final id = _generateDeviceId();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  String _generateDeviceId() {
    final rand = Random();
    final now = DateTime.now().millisecondsSinceEpoch;
    const maxRand = 1 << 31;
    final salt = rand.nextInt(maxRand).toUnsigned(32);
    return 'dev-$now-$salt';
  }
}
