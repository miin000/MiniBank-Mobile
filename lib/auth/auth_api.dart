import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';
import '../profile/profile_models.dart';

class AuthApi {
  final String baseUrl;

  AuthApi({required this.baseUrl});

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  Future<AuthResponse> login({
    required String phone,
    required String password,
    required String deviceId,
  }) async {
    final res = await http.post(
      _uri('/api/mobile/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': phone,
        'password': password,
        'deviceId': deviceId,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = res.body.isNotEmpty
          ? res.body
          : 'Login failed (status ${res.statusCode})';
      throw Exception(message);
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthResponse> register({
    required String phone,
    required String email,
    required String password,
    required String deviceId,
    String? fullName,
  }) async {
    final res = await http.post(
      _uri('/api/mobile/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'email': email,
        'password': password,
        'deviceId': deviceId,
        'fullName': fullName,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = res.body.isNotEmpty
          ? res.body
          : 'Register failed (status ${res.statusCode})';
      throw Exception(message);
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProfileResponse> getProfile({required String token}) async {
    final res = await http.get(
      _uri('/api/mobile/profile/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = res.body.isNotEmpty
          ? res.body
          : 'Profile load failed (status ${res.statusCode})';
      throw Exception(message);
    }

    return ProfileResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<ProfileResponse> updateProfile({
    required String token,
    String? fullName,
    DateTime? dob,
    String? address,
  }) async {
    String? dobValue;
    if (dob != null) {
      final iso = dob.toIso8601String();
      dobValue = iso.split('T').first;
    }

    final res = await http.put(
      _uri('/api/mobile/profile/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fullName': fullName,
        'dob': dobValue,
        'address': address,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = res.body.isNotEmpty
          ? res.body
          : 'Update profile failed (status ${res.statusCode})';
      throw Exception(message);
    }

    return ProfileResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await http.post(
      _uri('/api/mobile/profile/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = res.body.isNotEmpty
          ? res.body
          : 'Change password failed (status ${res.statusCode})';
      throw Exception(message);
    }
  }

  Future<void> setTransactionPin({
    required String token,
    String? oldPin,
    required String newPin,
  }) async {
    final body = {
      'newPin': newPin,
    };
    if (oldPin != null && oldPin.isNotEmpty) {
      body['oldPin'] = oldPin;
    }

    final res = await http.post(
      _uri('/api/mobile/profile/transaction-pin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = res.body.isNotEmpty
          ? res.body
          : 'Set PIN failed (status ${res.statusCode})';
      throw Exception(message);
    }
  }
}
