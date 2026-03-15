// lib/core/network/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/features/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  // ── 공통 헤더 ──────────────────────────────────
  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: AppConfig.tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── 토큰 재발급 ────────────────────────────────
  Future<bool> _reissue() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    if (refreshToken == null) return false;

    final result = await _authService.reissue(refreshToken);
    return result != null;
  }

  // ── GET ────────────────────────────────────────
  Future<http.Response> get(String path) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _handleUnauthorized(response, () => get(path));
  }

  // ── POST (JSON) ────────────────────────────────
  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleUnauthorized(response, () => post(path, body: body));
  }

  // ── POST (Multipart) ───────────────────────────
  Future<http.Response> postMultipart(
      String path, {
        required List<http.MultipartFile> files,
        Map<String, String>? fields,
      }) async {
    final token = await _storage.read(key: AppConfig.tokenKey);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}$path'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (fields != null) request.fields.addAll(fields);
    request.files.addAll(files);

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    return _handleUnauthorized(
      response,
          () => postMultipart(path, files: files, fields: fields),
    );
  }

  // ── POST (MultipartStream) ───────────────────────────
  Future<http.StreamedResponse> postMultipartStream(
      String path, {
        required List<http.MultipartFile> files,
        Map<String, String>? fields,
      }) async {
    final token = await _storage.read(key: AppConfig.tokenKey);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}$path'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'text/event-stream';
    if (fields != null) request.fields.addAll(fields);
    request.files.addAll(files);

    final client = http.Client();
    final streamed = await client.send(request);

    if (streamed.statusCode == 401) {
      client.close();
      final refreshed = await _reissue();
      if (refreshed) {
        return postMultipartStream(path, files: files, fields: fields);
      }
      throw UnauthorizedException();
    }

    return streamed;
  }

  // ── 401 처리 (토큰 재발급 후 재시도) ───────────
  Future<http.Response> _handleUnauthorized(
      http.Response response,
      Future<http.Response> Function() retry,
      ) async {
    if (response.statusCode == 401) {
      final refreshed = await _reissue();
      if (refreshed) {
        return retry(); // 재발급 성공 → 재시도
      }
      // 재발급 실패 → 로그아웃 필요 신호
      throw UnauthorizedException();
    }
    return response;
  }
}

// 로그아웃 필요 시 던지는 예외
class UnauthorizedException implements Exception {}