// lib/core/ads/ad_config_provider.dart
//
// 서버에서 광고 노출 설정을 받아오는 Provider.
//   1. load() 시 SharedPreferences 캐시를 먼저 적용해 즉시 사용 가능 상태로 진입
//   2. 백그라운드에서 /api/config/ads 호출, 성공 시 메모리/캐시 갱신 후 notify
//   3. 서버 미수신 / 네트워크 오류 시 마지막 캐시 또는 null 유지
//
// config == null 일 때 helper 들은 안전한 기본값(노출 허용 + 빌트인 단위 ID)을 반환하므로
// 서버가 죽어도 앱은 평소처럼 광고를 노출한다 — graceful degradation.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';

class AdConfigProvider extends ChangeNotifier {
  static const String _cacheKey = 'ad_config_cache_v1';

  AdConfig? _config;
  AdConfig? get config => _config;

  /// 위치 노출 여부. 컨피그 미수신 시 true (앱 빌트인 동작 유지).
  bool isPlacementEnabled(String key) {
    final p = _config?.placement(key);
    if (p == null) return true;
    return p.enabled;
  }

  /// 위치별 Android 광고 단위 ID 오버라이드. 컨피그/오버라이드 없으면 null → 빌트인 사용.
  String? adUnitIdAndroid(String key) => _config?.placement(key)?.adUnitIdAndroid;

  /// 전면광고 빈도 제한. null/1 이면 매번 노출.
  int? frequencyCap(String key) => _config?.placement(key)?.frequencyCap;

  Future<void> load() async {
    await _loadFromCache();
    await _refreshFromServer();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _config = AdConfig.fromJson(decoded);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AdConfig 캐시 로드 실패: $e');
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final response = await ApiClient().get('/api/config/ads');
      if (response.statusCode != 200) {
        debugPrint('AdConfig 응답 오류 status=${response.statusCode}');
        return;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return;

      _config = AdConfig.fromJson(decoded);
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(decoded));
      } catch (e) {
        debugPrint('AdConfig 캐시 저장 실패: $e');
      }
    } catch (e) {
      debugPrint('AdConfig 서버 조회 실패: $e');
    }
  }
}
