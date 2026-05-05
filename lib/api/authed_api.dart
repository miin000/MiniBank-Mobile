import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_storage.dart';

class AuthedApi {
  final String baseUrl;
  final AuthStorage storage;

  AuthedApi({required this.baseUrl, required this.storage});

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final token = await storage.getToken();
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    return headers;
  }

  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    required T Function(Object? decoded) parser,
  }) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
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
    final res = await http.post(
      _uri(path),
      headers: await _headers(jsonBody: true),
      body: jsonEncode(body),
    );
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
    final res = await http.put(
      _uri(path),
      headers: await _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Request failed');
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    return parser(decoded);
  }
}
