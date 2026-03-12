// lib/features/auth/auth_service.dart
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:miritalk_app/core/config/app_config.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.androidClientID,
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 성공 시 사용자 정보 Map 반환, 실패 시 null 반환
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
        final data = jsonDecode(response.body);
        await _storage.write(key: AppConfig.tokenKey, value: data['accessToken']);
        await _storage.write(key: 'refreshToken', value: data['refreshToken']);

        // 프로필 정보도 SecureStorage에 캐싱
        await _storage.write(key: 'profileImageUrl', value: data['profileImageUrl']);
        await _storage.write(key: 'userName', value: data['userName']);
        await _storage.write(key: 'userEmail', value: data['userEmail']);

        return {
          'profileImageUrl': data['profileImageUrl'],
          'userName': data['userName'],
          'userEmail': data['userEmail'],
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.deleteAll(); // 모든 저장값 삭제
  }

  Future<String?> getToken() => _storage.read(key: AppConfig.tokenKey);
  Future<bool> isLoggedIn() async => await getToken() != null;
}