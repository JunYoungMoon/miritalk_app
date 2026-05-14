// lib/features/notification_guard/services/risk_keyword_repository.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/features/notification_guard/models/risk_keyword.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 활성 위험 키워드 사전을 로컬에 캐시.
///
/// - 디스크 저장: SharedPreferences (`risk_keywords_json`, `risk_keywords_etag`,
///   `risk_keywords_version`, `risk_keywords_last_fetched`)
/// - 메모리 캐시: 같은 프로세스 내 재호출 비용 절감용. 디스크 갱신 시 invalidate.
/// - 폴링: 프로세스 부팅 후 첫 호출은 무조건 fetch(서버측 마이그레이션 직후
///   stale 1시간 윈도우를 피하기 위함). 그 후로는 1시간 TTL + ETag 조건부.
/// - version: 서버 응답의 `version` 필드를 디스크에 보관해 ETag 미발급 환경의
///   백업 무효화 신호로 사용.
/// - 동시 호출 가드: forceRefresh / refreshIfStale 가 동시에 들어와도 in-flight
///   하나로 합쳐 네트워크 중복 호출을 막는다 (부팅 시 `_start` 동기 fetch +
///   bootstrap 비동기 fetch 가 동시에 시작할 수 있어서).
class RiskKeywordRepository {
  RiskKeywordRepository._();
  static final RiskKeywordRepository instance = RiskKeywordRepository._();

  static const String _kDictKey       = 'risk_keywords_json';
  static const String _kEtagKey       = 'risk_keywords_etag';
  static const String _kVersionKey    = 'risk_keywords_version';
  static const String _kLastFetched   = 'risk_keywords_last_fetched';
  static const Duration _stalePeriod  = Duration(hours: 1);

  List<RiskKeyword>? _memCache;

  // 이 프로세스 라이프타임 동안 한 번이라도 fetch 시도했는지.
  // false 인 동안엔 TTL 무시하고 무조건 서버 호출 — V30 같은 마이그레이션
  // 직후 stale 캐시가 1시간 동안 사용자를 잡아두는 문제 방지.
  bool _refreshedThisSession = false;

  // 진행 중인 _forceRefresh Future. 같은 process 에서 동시 호출이 들어오면
  // 새 fetch 를 시작하지 않고 이 Future 를 기다린다.
  Future<void>? _inFlightFetch;

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

  /// 프로세스 부팅 후 첫 호출은 무조건 fetch (TTL 무시).
  /// 그 후엔 1시간 이상 지났거나 캐시가 비어 있을 때만 fetch.
  /// fire-and-forget 으로 호출 가능 — 실패해도 throw 하지 않고 로그만 남김.
  Future<void> refreshIfStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchedMs = prefs.getInt(_kLastFetched);
      final hasCache = (prefs.getString(_kDictKey) ?? '').isNotEmpty;
      if (_refreshedThisSession && hasCache && lastFetchedMs != null) {
        final last = DateTime.fromMillisecondsSinceEpoch(lastFetchedMs);
        if (DateTime.now().difference(last) < _stalePeriod) {
          return; // 부팅 후 한 번은 받았고 아직 fresh — 네트워크 호출 생략
        }
      }
      await _runForceRefresh(prefs);
      _refreshedThisSession = true;
    } catch (e) {
      debugPrint('risk_keywords refreshIfStale 실패 (캐시 유지): $e');
    }
  }

  /// 설정 화면에서 사용자가 "사전 강제 갱신" 버튼을 누를 때 등 즉시 갱신용.
  Future<void> forceRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    await _runForceRefresh(prefs);
  }

  /// 동시 호출 가드 진입점 — 이미 진행 중인 fetch 가 있으면 그것을 기다린다.
  Future<void> _runForceRefresh(SharedPreferences prefs) async {
    if (_inFlightFetch != null) {
      await _inFlightFetch;
      return;
    }
    _inFlightFetch = _forceRefresh(prefs).whenComplete(() => _inFlightFetch = null);
    await _inFlightFetch;
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
    final newVersion = (root['version'] as num?)?.toInt();

    await prefs.setString(_kDictKey, jsonEncode(keywordsJson));
    if (newEtag != null && newEtag.isNotEmpty) {
      await prefs.setString(_kEtagKey, newEtag);
    }
    if (newVersion != null) {
      await prefs.setInt(_kVersionKey, newVersion);
    }
    await prefs.setInt(_kLastFetched, DateTime.now().millisecondsSinceEpoch);

    _memCache = null; // 다음 getKeywords() 호출에서 다시 로드
  }
}
