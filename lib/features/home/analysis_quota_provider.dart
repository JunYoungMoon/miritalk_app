// lib/features/home/analysis_quota_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';

class AnalysisQuotaProvider extends ChangeNotifier {
  int _usedCount = 0;
  int _maxCount = 3;
  bool _isLoading = false;
  bool _isGuest = true;

  int get usedCount => _usedCount;
  int get maxCount => _maxCount;
  bool get isLoading => _isLoading;
  bool get isGuest => _isGuest;
  bool get isExhausted => _usedCount >= _maxCount;
  int get remaining => (_maxCount - _usedCount).clamp(0, _maxCount);

  /// 로그아웃 시 호출 — 게스트 쿼터로 전환
  Future<void> clear() async {
    await loadQuota(isLoggedIn: false);
  }

  /// 로그인 여부에 따라 서버에서 쿼터 조회
  Future<void> loadQuota({bool isLoggedIn = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (isLoggedIn) {
        await _loadMemberQuota();
      } else {
        await _loadGuestQuota();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 로그인 유저: 기존 서버 API
  Future<void> _loadMemberQuota() async {
    _isGuest = false;
    try {
      final response = await ApiClient().get('/api/fraud/quota/daily');
      if (response.statusCode == 200) {
        final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _usedCount = data['usedCount'] as int? ?? 0;
        _maxCount = data['maxCount'] as int? ?? 3;
      }
    } on UnauthorizedException {
      _usedCount = 0;
      _maxCount = 3;
    } catch (_) {
      // 네트워크 오류 시 기존 값 유지
    }
  }

  /// 게스트: Android ID를 헤더에 담아 서버에서 쿼터 조회
  Future<void> _loadGuestQuota() async {
    _isGuest = true;
    _maxCount = 1; // 게스트 최대 1회 (서버 응답으로 덮어씌워짐)
    try {
      final response = await ApiClient().get(
        '/api/fraud/quota/daily',
        includeDeviceId: true,
      );
      if (response.statusCode == 200) {
        final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _usedCount = data['usedCount'] as int? ?? 0;
        _maxCount = data['maxCount'] as int? ?? 1;
      }
    } catch (_) {
      // 조회 실패 시 보수적으로 소진 처리
      _usedCount = 1;
    }
  }

  /// 분석 완료 후 로컬 카운트 즉시 증가 (서버 재조회 전 UX)
  void incrementLocal() {
    if (_usedCount < _maxCount) {
      _usedCount++;
      notifyListeners();
    }
  }
}