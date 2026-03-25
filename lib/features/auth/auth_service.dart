// lib/features/auth/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:miritalk_app/core/config/app_config.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.androidClientID,
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String?>?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) return null;

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        return await _saveAndReturn(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('구글 로그인 에러: $e');
      return null;
    }
  }

  Future<Map<String, String?>?> signInWithKakao() async {
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accessToken': token.accessToken}),
      );

      if (response.statusCode == 200) {
        return await _saveAndReturn(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('카카오 로그인 오류: $e');
      return null;
    }
  }

  Future<Map<String, String?>?> reissue(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/reissue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: AppConfig.tokenKey, value: data['accessToken']);
        await _storage.write(key: 'refreshToken',     value: data['refreshToken']);
        return {
          'accessToken':  data['accessToken'],
          'refreshToken': data['refreshToken'],
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    // 구글 로그아웃
    try { await _googleSignIn.signOut(); } catch (_) {}
    // 카카오 로그아웃
    try { await UserApi.instance.logout(); } catch (_) {}
    await _storage.deleteAll();
  }

  Future<String?> getToken() => _storage.read(key: AppConfig.tokenKey);
  Future<bool> isLoggedIn() async => await getToken() != null;

  // 공통 저장 로직 분리
  Future<Map<String, String?>?> _saveAndReturn(Map<String, dynamic> data) async {
    await _storage.write(key: AppConfig.tokenKey, value: data['accessToken']);
    await _storage.write(key: 'refreshToken',     value: data['refreshToken']);
    await _storage.write(key: 'profileImageUrl',  value: data['profileImageUrl']);
    await _storage.write(key: 'userName',         value: data['userName']);
    await _storage.write(key: 'userEmail',        value: data['userEmail']);
    return {
      'accessToken':     data['accessToken'],
      'refreshToken':    data['refreshToken'],
      'profileImageUrl': data['profileImageUrl'],
      'userName':        data['userName'],
      'userEmail':       data['userEmail'],
    };
  }
}