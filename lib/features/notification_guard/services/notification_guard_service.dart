import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:miritalk_app/features/notification_guard/models/notification_judge_response.dart';
import 'package:miritalk_app/features/notification_guard/services/notification_buffer.dart';
import 'package:miritalk_app/features/notification_guard/services/notification_guard_api.dart';
import 'package:miritalk_app/features/notification_guard/services/notification_scorer.dart';
import 'package:miritalk_app/features/notification_guard/services/risk_keyword_repository.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 사기 사전 차단 — 진입점.
///
/// 라이프사이클:
///   1) `bootstrap()` — main.dart 에서 한 번 호출. 권한·기능 ON 이면 리스너 바인딩.
///   2) `enable()` / `disable()` — 설정 화면 토글에서 호출.
///   3) `isPermissionGranted()` / `requestPermission()` — 권한 흐름 위임.
///
/// 자기 자신의 패키지(미리톡)에서 발생한 알림은 무시 — 무한 루프 방지
/// (이 서비스가 SUSPICIOUS 시 띄우는 로컬 알림까지 다시 잡으면 안 됨).
class NotificationGuardService {
  NotificationGuardService._();
  static final NotificationGuardService instance = NotificationGuardService._();

  /// OpenAI 호출 임계 점수. V27 점수 가이드 기준 50 이 표준.
  /// 테스트할 때만 30 정도로 낮춰서 흐름 확인, 출시 시점에 50 복귀.
  /// 운영 데이터 보고 false positive 가 많으면 60~70 으로 보수화.
  static const int kThresholdScore = 50;

  // SharedPreferences 키
  static const String _kEnabledKey = 'notification_guard_enabled';

  // 경고용 로컬 알림 채널
  static const String _channelId = 'miritalk_notification_guard';
  static const String _channelName = '사기 알림 사전 차단';
  static const String _channelDesc = '의심 알림을 감지했을 때 경고를 보냅니다.';

  // 무시할 패키지 (자기 자신 + 시스템 UI)
  static const Set<String> _ignoredPackages = {
    'com.miritalk.miritalk_app',
    'com.android.systemui',
    'android',
  };

  StreamSubscription<ServiceNotificationEvent>? _subscription;
  NotificationBuffer? _buffer;
  NotificationScorer? _scorer;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _running = false;
  bool get isRunning => _running;

  // ── public API ────────────────────────────────────────────────

  /// 앱 부팅 시 main.dart 에서 호출. iOS 면 no-op.
  Future<void> bootstrap() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;
    _initialized = true;

    await _ensureChannel();

    final enabled = await isEnabled();
    if (!enabled) return;
    final granted = await NotificationListenerService.isPermissionGranted();
    if (!granted) return;

    // 사전 갱신은 비동기 — 첫 매칭에 사전이 없으면 매칭 0건으로 떨어질 뿐, 부팅을 막지 않음.
    // ignore: unawaited_futures
    RiskKeywordRepository.instance.refreshIfStale();
    await _start();
  }

  Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? false;
  }

  Future<void> enable() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, true);
    // ignore: unawaited_futures
    RiskKeywordRepository.instance.refreshIfStale();
    await _start();
  }

  Future<void> disable() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, false);
    await _stop();
  }

  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    return NotificationListenerService.isPermissionGranted();
  }

  /// 권한 요청 — OS 설정 페이지로 이동. 사용자가 동의 후 앱으로 복귀하면 true.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    return NotificationListenerService.requestPermission();
  }

  // ── 내부 ───────────────────────────────────────────────────────

  Future<void> _start() async {
    if (_running) return;
    final keywords = await RiskKeywordRepository.instance.getKeywords();
    _scorer = NotificationScorer(keywords);
    _buffer = NotificationBuffer(
      onFlush: _onBufferFlush,
      thresholdScore: kThresholdScore,
    );

    _subscription = NotificationListenerService
        .notificationsStream
        .listen(_onNotificationEvent, onError: (Object e) {
      debugPrint('NotificationListener 스트림 오류: $e');
    });
    _running = true;
    debugPrint('NotificationGuard 시작 — 사전 ${keywords.length}건');
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _buffer?.dispose();
    _buffer = null;
    _scorer = null;
    _running = false;
    debugPrint('NotificationGuard 중지');
  }

  void _onNotificationEvent(ServiceNotificationEvent event) {
    // 알림 해제 이벤트는 무시 (사용자가 알림 스와이프할 때 발생)
    if (event.hasRemoved == true) return;

    final pkg = event.packageName ?? '';
    if (pkg.isEmpty || _ignoredPackages.contains(pkg)) return;

    final title = event.title ?? '';
    final content = event.content ?? '';
    final merged = _mergeTitleContent(title, content);
    if (merged.isEmpty) return;

    final scorer = _scorer;
    final buffer = _buffer;
    if (scorer == null || buffer == null) return;

    final firstScore = scorer.score(merged).total;
    buffer.ingest(
      packageName: pkg,
      sender: title.isNotEmpty ? title : '(발신자 없음)',
      text: merged,
      score: firstScore,
      rescoreFn: (full) => scorer.score(full).total,
    );
  }

  Future<void> _onBufferFlush(BufferFlush flush) async {
    final scorer = _scorer;
    if (scorer == null) return;

    final scoring = scorer.score(flush.text);
    if (scoring.total <= 0 || scoring.signals.isEmpty) return;

    final resp = await NotificationGuardApi.instance.judge(
      packageName: flush.packageName,
      sender: flush.sender,
      text: flush.text,
      localScore: scoring.total,
      signals: scoring.signals,
    );
    if (resp == null) return;
    if (!resp.isSuspicious) return;
    await _showWarning(flush, resp);
  }

  static String _mergeTitleContent(String title, String content) {
    if (title.isEmpty) return content;
    if (content.isEmpty) return title;
    return '$title: $content';
  }

  Future<void> _ensureChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showWarning(BufferFlush flush, NotificationJudgeResponse resp) async {
    final notifId = (flush.sender + flush.packageName).hashCode & 0x7fffffff;
    final payload = jsonEncode({
      'type': 'NOTIFICATION_GUARD_WARNING',
      'packageName': flush.packageName,
      'sender': flush.sender,
      'riskScore': resp.riskScore,
      'summary': resp.summary,
    });

    final reasonsLine = resp.reasons.isEmpty
        ? ''
        : '\n• ${resp.reasons.take(3).join("\n• ")}';
    final bigText = '${resp.summary}$reasonsLine';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        styleInformation: BigTextStyleInformation(
          bigText,
          contentTitle: '⚠️ 사기 의심 알림이 도착했어요',
          summaryText: '${flush.sender} · 위험도 ${resp.riskScore}',
        ),
      ),
    );

    await _localNotifications.show(
      notifId,
      '⚠️ 사기 의심 알림이 도착했어요',
      '${flush.sender} · 위험도 ${resp.riskScore}',
      details,
      payload: payload,
    );
  }
}
