// lib/features/auth/auth_provider.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/features/home/conversation_provider.dart';

enum LoginType { none, google, kakao }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  ConversationProvider? _conversationProvider;

  bool _isLoading = false;
  LoginType _loadingType = LoginType.none;
  bool _isLoggedIn = false;
  String? _errorMessage;
  String? _profileImageUrl;
  String? _userName;
  String? _userEmail;
  String? _accessToken;
  String? _refreshToken;

  bool get isLoading => _isLoading;
  LoginType get loadingType => _loadingType;
  bool get isGoogleLoading => _loadingType == LoginType.google;
  bool get isKakaoLoading  => _loadingType == LoginType.kakao;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;
  String? get profileImageUrl => _profileImageUrl;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool _isWithdrawing = false;
  bool get isWithdrawing => _isWithdrawing;

  void setConversationProvider(ConversationProvider provider) {
    _conversationProvider = provider;
  }

  Future<void> signInWithGoogle() async {
    await _login(
          () => _authService.signInWithGoogle(),
      type: LoginType.google,
      errorMsg: '구글 로그인에 실패했습니다.',
    );
  }

  Future<void> signInWithKakao() async {
    await _login(
          () => _authService.signInWithKakao(),
      type: LoginType.kakao,
      errorMsg: '카카오 로그인에 실패했습니다.',
    );
  }

  Future<void> _login(
      Future<Map<String, String?>?> Function() loginFn, {
        required LoginType type,
        required String errorMsg,
      }) async {
    _isLoading   = true;
    _loadingType = type;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await loginFn();
      _isLoading   = false;
      _loadingType = LoginType.none;
      if (result != null) {
        _isLoggedIn      = true;
        _profileImageUrl = result['profileImageUrl'];
        _userName        = result['userName'];
        _userEmail       = result['userEmail'];
        _accessToken     = result['accessToken'];
        _refreshToken    = result['refreshToken'];
      } else {
        _isLoggedIn   = false;
        _errorMessage = errorMsg;
      }
    } catch (e) {
      _isLoading   = false;
      _loadingType = LoginType.none;
      _isLoggedIn  = false;
      _errorMessage = e is WithdrawnAccountException
          ? '탈퇴한 계정입니다.'
          : errorMsg;
    }

    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      final storage = const FlutterSecureStorage();
      _accessToken     = await storage.read(key: AppConfig.tokenKey);
      _refreshToken    = await storage.read(key: 'refreshToken');
      _profileImageUrl = await storage.read(key: 'profileImageUrl');
      _userName        = await storage.read(key: 'userName');
      _userEmail       = await storage.read(key: 'userEmail');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.signOut();
    _isLoggedIn      = false;
    _profileImageUrl = null;
    _userName        = null;
    _userEmail       = null;
    _accessToken     = null;
    _refreshToken    = null;
    _conversationProvider?.clear();
    notifyListeners();
  }

  Future<WithdrawResult> withdraw() async {
    _isWithdrawing = true;
    notifyListeners();

    final result = await _authService.withdraw();

    _isWithdrawing = false;

    if (result == WithdrawResult.success) {
      _isLoggedIn      = false;
      _profileImageUrl = null;
      _userName        = null;
      _userEmail       = null;
      _accessToken     = null;
      _refreshToken    = null;
      _conversationProvider?.clear();
    }

    notifyListeners();
    return result;
  }
}