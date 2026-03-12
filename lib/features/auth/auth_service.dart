import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:miritalk_app/core/config/app_config.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '888192694933-gvuvi0ob5a26e2dnskcbd0mkc0o1c32u.apps.googleusercontent.com',
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        print('=== 로그인 취소됨 ===');
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) {
        print('=== idToken이 null ===');
        return false;
      }

      print('=== idToken 획득 성공 ===');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      print('=== 서버 응답 코드: ${response.statusCode} ===');
      print('=== 서버 응답 바디: ${response.body} ===');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: AppConfig.tokenKey, value: data['accessToken']);
        return true;
      }
      return false;
    } catch (e, stack) {
      print('=== 에러 발생: $e ===');
      print('=== 스택: $stack ===');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.delete(key: AppConfig.tokenKey);
  }

  Future<String?> getToken() => _storage.read(key: AppConfig.tokenKey);
  Future<bool> isLoggedIn() async => await getToken() != null;
}