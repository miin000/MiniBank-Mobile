import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';

class AuthApi {
  final String baseUrl;

  AuthApi({required this.baseUrl});

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  Future<AuthResponse> login({required String phone, required String password}) async {
    final res = await http.post(
      _uri('/api/mobile/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': phone, 'password': password}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Login failed');
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthResponse> register({
    required String phone,
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await http.post(
      _uri('/api/mobile/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'email': email,
        'password': password,
        'fullName': fullName,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Register failed');
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
