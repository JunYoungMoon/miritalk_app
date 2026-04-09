// lib/core/tracking/tracking_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ── 화면 진입 ──
  Future<void> logScreen(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // ── 분석 요청 ──
  Future<void> logAnalysisRequested({required int imageCount, required bool isGuest}) async {
    await _analytics.logEvent(name: 'analysis_requested', parameters: {
      'image_count': imageCount,
      'is_guest': isGuest ? 1 : 0,
    });
  }

  // ── 분석 완료 ──
  Future<void> logAnalysisCompleted({required int riskScore, required String riskLevel}) async {
    await _analytics.logEvent(name: 'analysis_completed', parameters: {
      'risk_score': riskScore,
      'risk_level': riskLevel,
    });
  }

  // ── 로그인 시도 ──
  Future<void> logLoginAttempt(String method) async {
    await _analytics.logEvent(name: 'login_attempt', parameters: {'method': method});
  }

  // ── 로그인 성공 ──
  Future<void> logLoginSuccess(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  // ── 게스트 → 로그인 유도 탭 ──
  Future<void> logGuestToLoginTap(String trigger) async {
    await _analytics.logEvent(name: 'guest_to_login_tap', parameters: {'trigger': trigger});
  }

  // ── 분석 이탈 (업로드 화면에서 뒤로가기) ──
  Future<void> logUploadAbandoned(int imageCount) async {
    await _analytics.logEvent(name: 'upload_abandoned', parameters: {
      'image_count': imageCount,
    });
  }

  // ── 피드백 제출 ──
  Future<void> logFeedbackSubmitted({required bool helpful, String? reason}) async {
    await _analytics.logEvent(name: 'feedback_submitted', parameters: {
      'helpful': helpful ? 1 : 0,
      if (reason != null) 'reason': reason,
    });
  }

  // ── 할당량 초과 ──
  Future<void> logQuotaExhausted({required bool isGuest}) async {
    await _analytics.logEvent(name: 'quota_exhausted', parameters: {
      'is_guest': isGuest ? 1 : 0,
    });
  }

  // ── 앱 백그라운드 전환 ──
  Future<void> logAppBackgrounded() async {
    await _analytics.logEvent(name: 'app_backgrounded');
  }

  // ── 앱 포그라운드 복귀 ──
  Future<void> logAppResumed() async {
    await _analytics.logEvent(name: 'app_resumed');
  }

  // ── 앱 종료 ──
  Future<void> logAppTerminated() async {
    await _analytics.logEvent(name: 'app_terminated');
  }
}