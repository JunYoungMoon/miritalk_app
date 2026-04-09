// lib/features/auth/auth_service.dart — 전체

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ── 클래스 밖에 선언 ──
enum WithdrawResult { success, notFound, error }

class WithdrawnAccountException implements Exception {}

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
      } else if (response.statusCode == 403) {
        throw WithdrawnAccountException();
      }
      return null;
    } catch (e) {
      debugPrint('구글 로그인 에러: $e');
      rethrow;
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
      } else if (response.statusCode == 403) {
        throw WithdrawnAccountException();
      }
      return null;
    } catch (e) {
      debugPrint('카카오 로그인 오류: $e');
      rethrow;
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
        await _storage.write(key: 'refreshToken', value: data['refreshToken']);
        return {
          'accessToken': data['accessToken'],
          'refreshToken': data['refreshToken'],
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<WithdrawResult> withdraw() async {
    try {
      final token = await _storage.read(key: AppConfig.tokenKey);
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/auth/withdraw'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      switch (response.statusCode) {
        case 204:
          await signOut();
          return WithdrawResult.success;
        case 404:
          return WithdrawResult.notFound;
        default:
          return WithdrawResult.error;
      }
    } catch (e) {
      debugPrint('회원 탈퇴 오류: $e');
      return WithdrawResult.error;
    }
  }

  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await UserApi.instance.logout(); } catch (_) {}
    await _storage.deleteAll();
  }

  Future<String?> getToken() => _storage.read(key: AppConfig.tokenKey);
  Future<bool> isLoggedIn() async => await getToken() != null;

  Future<Map<String, String?>?> _saveAndReturn(Map<String, dynamic> data) async {
    await _storage.write(key: AppConfig.tokenKey, value: data['accessToken']);
    await _storage.write(key: 'refreshToken', value: data['refreshToken']);
    await _storage.write(key: 'profileImageUrl', value: data['profileImageUrl']);
    await _storage.write(key: 'userName', value: data['userName']);
    await _storage.write(key: 'userEmail', value: data['userEmail']);

    // ── 로그인 직후 FCM 토큰 서버 등록 ──
    await _registerFcmToken(data['accessToken']);

    return {
      'accessToken': data['accessToken'],
      'refreshToken': data['refreshToken'],
      'profileImageUrl': data['profileImageUrl'],
      'userName': data['userName'],
      'userEmail': data['userEmail'],
    };
  }

  Future<void> _registerFcmToken(String? accessToken) async {
    if (accessToken == null) return;
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/user/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'token': fcmToken}),
      );
    } catch (e) {
      debugPrint('FCM 토큰 등록 실패: $e');
      // FCM 등록 실패가 로그인 자체를 막으면 안 되므로 예외 삼킴
    }
  }

  Future<int> transferGuestSessions(String accessToken, String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/fraud/transfer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'deviceId': deviceId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['transferred'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint('세션 이전 실패: $e');
    }
    return 0;
  }
}