import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/features/notification_guard/models/risk_keyword.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 활성 위험 키워드 사전을 로컬에 캐시.
///
/// - 디스크 저장: SharedPreferences (`risk_keywords_json`, `risk_keywords_etag`,
///   `risk_keywords_last_fetched`)
/// - 메모리 캐시: 같은 프로세스 내 재호출 비용 절감용. 디스크 갱신 시 invalidate.
/// - 폴링: 1시간마다 ETag 조건부 호출 → 304 면 그대로, 200 이면 교체.
class RiskKeywordRepository {
  RiskKeywordRepository._();
  static final RiskKeywordRepository instance = RiskKeywordRepository._();

  static const String _kDictKey       = 'risk_keywords_json';
  static const String _kEtagKey       = 'risk_keywords_etag';
  static const String _kLastFetched   = 'risk_keywords_last_fetched';
  static const Duration _stalePeriod  = Duration(hours: 1);

  List<RiskKeyword>? _memCache;

  Future<List<RiskKeyword>> getKeywords() async {
    if (_memCache != null) return _memCache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDictKey);
    if (raw == null || raw.isEmpty) {
      _memCache = const <RiskKeyword>[];
      return _memCache!;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(RiskKeyword.fromJson)
          .toList();
      _memCache = List.unmodifiable(list);
      return _memCache!;
    } catch (e) {
      debugPrint('risk_keywords 캐시 파싱 실패: $e');
      _memCache = const <RiskKeyword>[];
      return _memCache!;
    }
  }

  /// 마지막 fetch 시각이 1시간 이상 지났거나, 캐시가 비어 있으면 서버에서 갱신.
  /// 결과는 디스크에 저장하고 메모리 캐시도 invalidate.
  ///
  /// fire-and-forget 으로 호출 가능 — 실패해도 throw 하지 않고 로그만 남김.
  Future<void> refreshIfStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchedMs = prefs.getInt(_kLastFetched);
      final hasCache = (prefs.getString(_kDictKey) ?? '').isNotEmpty;
      if (hasCache && lastFetchedMs != null) {
        final last = DateTime.fromMillisecondsSinceEpoch(lastFetchedMs);
        if (DateTime.now().difference(last) < _stalePeriod) {
          return; // 아직 fresh — 네트워크 호출 생략
        }
      }
      await _forceRefresh(prefs);
    } catch (e) {
      debugPrint('risk_keywords refreshIfStale 실패 (캐시 유지): $e');
    }
  }

  /// 설정 화면에서 사용자가 "사전 강제 갱신" 버튼을 누를 때 등 즉시 갱신용.
  Future<void> forceRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    await _forceRefresh(prefs);
  }

  Future<void> _forceRefresh(SharedPreferences prefs) async {
    final etag = prefs.getString(_kEtagKey);
    final res = await ApiClient().get(
      '/api/risk/keywords',
      includeDeviceId: true,
      extraHeaders: etag != null ? {'If-None-Match': etag} : null,
    );

    // ApiClient.get 은 304 를 그대로 반환한다 — 본문 비어있음. 캐시 유지.
    if (res.statusCode == 304) {
      await prefs.setInt(_kLastFetched, DateTime.now().millisecondsSinceEpoch);
      return;
    }
    if (res.statusCode != 200) {
      debugPrint('risk_keywords 응답 비정상: ${res.statusCode}');
      return;
    }

    final body = utf8.decode(res.bodyBytes);
    final root = jsonDecode(body) as Map<String, dynamic>;
    final keywordsJson = (root['keywords'] as List).cast<Map<String, dynamic>>();
    final newEtag = res.headers['etag'];

    await prefs.setString(_kDictKey, jsonEncode(keywordsJson));
    if (newEtag != null && newEtag.isNotEmpty) {
      await prefs.setString(_kEtagKey, newEtag);
    }
    await prefs.setInt(_kLastFetched, DateTime.now().millisecondsSinceEpoch);

    _memCache = null; // 다음 getKeywords() 호출에서 다시 로드
    if (etag != newEtag) {
      debugPrint('risk_keywords 갱신됨: ${keywordsJson.length}건');
    }
  }
}
