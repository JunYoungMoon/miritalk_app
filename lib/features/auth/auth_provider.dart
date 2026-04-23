// lib/features/auth/auth_provider.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/core/cache/app_image_cache.dart';
import 'package:miritalk_app/features/home/conversation_provider.dart';
import 'package:miritalk_app/features/home/guest_quota_service.dart';

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
  LoginType _loginType = LoginType.none;

  bool _isWithdrawing = false;
  bool get isWithdrawing => _isWithdrawing;

  String? get loginProvider {
    switch (_loginType) {
      case LoginType.google: return 'Google';
      case LoginType.kakao:  return 'Kakao';
      case LoginType.none:   return null;
    }
  }

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
    _loginType = type;

    await const FlutterSecureStorage().write(
      key: 'loginType',
      value: type == LoginType.google ? 'google' : 'kakao',
    );

    try {
      final result = await loginFn();
      _isLoading   = false;
      _loadingType = LoginType.none;
      if (result != null) {
        // 로그인 성공 시 이전 캐시 초기화 (다른 계정 이미지 오염 방지)
        AppImageCache.instance.clear();

        _isLoggedIn      = true;
        _profileImageUrl = result['profileImageUrl'];
        _userName        = result['userName'];
        _userEmail       = result['userEmail'];
        _accessToken     = result['accessToken'];
        _refreshToken    = result['refreshToken'];

        // refresh: true 로 강제 갱신
        _conversationProvider?.loadConversations(refresh: true);
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
    final storage = const FlutterSecureStorage();
    final lt = await storage.read(key: 'loginType');
    _loginType = lt == 'kakao' ? LoginType.kakao : LoginType.google;
    if (_isLoggedIn) {
      _accessToken     = await storage.read(key: AppConfig.tokenKey);
      _refreshToken    = await storage.read(key: 'refreshToken');
      _profileImageUrl = await storage.read(key: 'profileImageUrl');
      _userName        = await storage.read(key: 'userName');
      _userEmail       = await storage.read(key: 'userEmail');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _loginType = LoginType.none;
    await _authService.signOut();
    _isLoggedIn      = false;
    _profileImageUrl = null;
    _userName        = null;
    _userEmail       = null;
    _accessToken     = null;
    _refreshToken    = null;
    _conversationProvider?.clear();
    AppImageCache.instance.clear();
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
      AppImageCache.instance.clear();
    }

    notifyListeners();
    return result;
  }
}