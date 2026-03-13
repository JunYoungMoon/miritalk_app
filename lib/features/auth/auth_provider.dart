// lib/features/auth/auth_provider.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:miritalk_app/core/config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _errorMessage;
  String? _profileImageUrl;
  String? _userName;
  String? _userEmail;
  String? _accessToken;
  String? _refreshToken;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;
  String? get profileImageUrl => _profileImageUrl;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signInWithGoogle();

    _isLoading = false;
    if (result != null) {
      _isLoggedIn = true;
      _profileImageUrl = result['profileImageUrl'];
      _userName = result['userName'];
      _userEmail = result['userEmail'];
      _accessToken = result['accessToken'];
      _refreshToken = result['refreshToken'];
    } else {
      _isLoggedIn = false;
      _errorMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
    }
    notifyListeners();
  }

  // auth_provider.dart에 추가
  Future<void> checkLoginStatus() async {
    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      // SecureStorage에서 저장된 정보 복원
      final storage = const FlutterSecureStorage();
      _accessToken = await storage.read(key: AppConfig.tokenKey);
      _refreshToken = await storage.read(key: 'refreshToken');
      _profileImageUrl = await storage.read(key: 'profileImageUrl');
      _userName = await storage.read(key: 'userName');
      _userEmail = await storage.read(key: 'userEmail');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.signOut();
    _isLoggedIn = false;
    _profileImageUrl = null;
    _userName = null;
    _userEmail = null;
    _accessToken = null;
    _refreshToken = null;
    notifyListeners();
  }
}