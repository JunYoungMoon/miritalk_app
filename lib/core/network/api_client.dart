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

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: AppConfig.tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _reissue() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    if (refreshToken == null) return false;
    final result = await _authService.reissue(refreshToken);
    return result != null;
  }

  Future<http.Response> get(String path) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _handleUnauthorized(response, () => get(path));
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleUnauthorized(response, () => post(path, body: body));
  }

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

    // ── 429 처리 추가 ──
    if (streamed.statusCode == 429) {
      client.close();
      // 서버 응답 바디에서 메시지 파싱 시도
      final body = await http.Response.fromStream(streamed);
      String message = '오늘 무료 분석 횟수(3회)를 모두 사용했습니다.\n내일 자정에 초기화됩니다.';
      try {
        final json = jsonDecode(utf8.decode(body.bodyBytes));
        if (json['message'] != null) message = json['message'] as String;
      } catch (_) {}
      throw QuotaExceededException(message);
    }

    return streamed;
  }

  Future<http.Response> _handleUnauthorized(
      http.Response response,
      Future<http.Response> Function() retry,
      ) async {
    if (response.statusCode == 401) {
      final refreshed = await _reissue();
      if (refreshed) return retry();
      throw UnauthorizedException();
    }
    return response;
  }
}

class UnauthorizedException implements Exception {}

// ── 신규 추가 ──
class QuotaExceededException implements Exception {
  final String message;
  const QuotaExceededException(this.message);
}