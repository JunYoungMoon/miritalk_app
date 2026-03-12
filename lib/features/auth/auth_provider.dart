// lib/features/auth/auth_provider.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _errorMessage;
  String? _profileImageUrl;
  String? _userName;
  String? _userEmail;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;
  String? get profileImageUrl => _profileImageUrl;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  Future<void> checkLoginStatus() async {
    _isLoggedIn = await _authService.isLoggedIn();
    notifyListeners();
  }

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
    } else {
      _isLoggedIn = false;
      _errorMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
    }
    notifyListeners();
  }

  // logout = signOut 으로 통일, SharedPreferences 제거
  Future<void> logout() async {
    await _authService.signOut();
    _isLoggedIn = false;
    _profileImageUrl = null;
    _userName = null;
    _userEmail = null;
    notifyListeners();
  }
}