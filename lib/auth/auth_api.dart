import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';

class AuthApi {
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

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
    String? publicKeyPem,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identifier': phone,
            'password': password,
            'deviceId': deviceId,
            'publicKey': publicKeyPem,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Login failed');
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthOtpSendResponse> sendLoginOtp({
    required String phone,
    required String deviceId,
    String? publicKeyPem,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/login/otp/send'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identifier': phone,
            'deviceId': deviceId,
            'publicKey': publicKeyPem,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Send OTP failed');
    }

    return AuthOtpSendResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthResponse> verifyLogin({
    required String phone,
    required String otpCode,
    required String deviceId,
    String? publicKeyPem,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/login/verify'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identifier': phone,
            'otpCode': otpCode,
            'deviceId': deviceId,
            'publicKey': publicKeyPem,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Verify login failed');
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> verifyPin(String pin, String token) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/pin/verify'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'pin': pin,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 428) {
      // PIN not set - this is handled specially
      throw Exception('PIN_NOT_SET');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Verify PIN failed');
    }
  }

  Future<AuthOtpSendResponse> sendPasswordResetOtp({
    required String phone,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/password/reset/otp/send'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identifier': phone,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Send OTP failed');
    }

    return AuthOtpSendResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> resetPassword({
    required String phone,
    required String otpCode,
    required String newPassword,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/password/reset/verify'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identifier': phone,
            'otpCode': otpCode,
            'newPassword': newPassword,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Reset password failed');
    }
  }

  Future<AuthOtpSendResponse> sendPinResetOtp({
    required String token,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/pin/reset/otp/send'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Send OTP failed');
    }

    return AuthOtpSendResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> resetPin({
    required String token,
    required String otpCode,
    required String newPin,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/pin/reset/verify'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'otpCode': otpCode,
            'newPin': newPin,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Reset PIN failed');
    }
  }

  Future<AuthResponse> register({
    required String phone,
    required String email,
    required String password,
    String? fullName,
    String? deviceId,
    String? publicKeyPem,
  }) async {
    final res = await http
        .post(
          _uri('/api/mobile/auth/register'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'phone': phone,
            'email': email,
            'password': password,
            'fullName': fullName,
            'deviceId': deviceId,
            'publicKey': publicKeyPem,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Register failed');
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
