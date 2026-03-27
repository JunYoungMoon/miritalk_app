// lib/features/home/analysis_quota_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';

class AnalysisQuotaProvider extends ChangeNotifier {
  int _usedCount = 0;
  int _maxCount = 3;
  bool _isLoading = false;

  int get usedCount => _usedCount;
  int get maxCount => _maxCount;
  bool get isLoading => _isLoading;
  bool get isExhausted => _usedCount >= _maxCount;
  int get remaining => (_maxCount - _usedCount).clamp(0, _maxCount);

  /// 로그아웃 시 호출 — 상태 초기화
  void clear() {
    _usedCount = 0;
    _maxCount = 3;
    _isLoading = false;
    notifyListeners();
  }

  /// 서버에서 오늘 사용 횟수 조회
  Future<void> loadQuota() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiClient().get('/api/fraud/quota/daily');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
        _usedCount = data['usedCount'] as int? ?? 0;
        _maxCount  = data['maxCount']  as int? ?? 3;
      }
    } on UnauthorizedException {
      // 로그아웃 상태면 0으로 초기화
      _usedCount = 0;
    } catch (_) {
      // 네트워크 오류 시 기존 값 유지
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 분석 완료 후 로컬에서 즉시 카운트 증가 (서버 재조회 전 UX)
  void incrementLocal() {
    if (_usedCount < _maxCount) {
      _usedCount++;
      notifyListeners();
    }
  }
}