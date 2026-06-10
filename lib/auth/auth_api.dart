import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';
import '../profile/profile_models.dart';

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
      final message = res.body.isNotEmpty
          ? res.body
          : 'Login failed (status ${res.statusCode})';
      throw Exception(message);
    }

    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthOtpSendResponse> sendLoginOtp({
    required String phone,
    required String password,
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
            'password': password,
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
    required String deviceId,
    String? fullName,
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
