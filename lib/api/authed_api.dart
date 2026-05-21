import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_storage.dart';

/// Thin HTTP wrapper that automatically attaches the JWT Bearer token
/// stored in [AuthStorage] to every outgoing request.
class AuthedApi {
  final String baseUrl;
  final AuthStorage storage;

  const AuthedApi({required this.baseUrl, required this.storage});

  Future<Map<String, String>> _headers() async {
    final token = await storage.getToken();
    return {
      'Content-Type' : 'application/json',
      'Accept'       : 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// HTTP GET
  Future<http.Response> get(String path) async {
    final headers = await _headers();
    return http.get(Uri.parse('$baseUrl$path'), headers: headers);
  }

  /// HTTP POST
  Future<http.Response> post(String path, {String? body}) async {
    final headers = await _headers();
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body,
    );
  }

  /// HTTP PUT
  Future<http.Response> put(String path, {String? body}) async {
    final headers = await _headers();
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body,
    );
  }

  /// HTTP PATCH
  Future<http.Response> patch(String path, {String? body}) async {
    final headers = await _headers();
    return http.patch(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body,
    );
  }

  /// HTTP DELETE
  Future<http.Response> delete(String path) async {
    final headers = await _headers();
    return http.delete(Uri.parse('$baseUrl$path'), headers: headers).timeout(const Duration(seconds: 30));
  }

  // ----------------- Backwards-compatible JSON helpers -----------------
  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    required T Function(Object? decoded) parser,
  }) async {
    final res = await get(path).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Request failed');
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    return parser(decoded);
  }

  Future<T> postJson<T>(
    String path, {
    Object? body,
    required T Function(Object? decoded) parser,
  }) async {
    final res = await post(path, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Request failed');
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    return parser(decoded);
  }

  Future<T> putJson<T>(
    String path, {
    Object? body,
    required T Function(Object? decoded) parser,
  }) async {
    final res = await put(path, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Request failed');
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    return parser(decoded);
  }

  Future<T> patchJson<T>(
    String path, {
    Object? body,
    required T Function(Object? decoded) parser,
  }) async {
    final res = await patch(path, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Request failed');
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    return parser(decoded);
  }
}
