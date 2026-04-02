// lib/core/notifications/fcm_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:miritalk_app/firebase_options.dart';

// ── 백그라운드 메시지 핸들러 (top-level 함수여야 함) ──
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // 분석 완료 알림 채널 ID
  static const String _channelId = 'miritalk_analysis';
  static const String _channelName = '분석 완료 알림';
  static const String _channelDesc = '사기 분석이 완료되면 알림을 보냅니다.';

  /// 앱 시작 시 한 번만 호출
  Future<void> initialize({
    /// 알림 탭 시 실행할 콜백 (sessionId 전달)
    required void Function(int sessionId) onAnalysisComplete,
  }) async {
    // 1. 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. 로컬 알림 초기화
    await _initLocalNotifications(onAnalysisComplete: onAnalysisComplete);

    // 3. 권한 요청
    await _requestPermission();

    // 4. FCM 토큰 서버 등록
    await _registerToken();

    // 5. 토큰 갱신 감지
    _messaging.onTokenRefresh.listen(_sendTokenToServer);

    // 6. 포그라운드 메시지 수신
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // 7. 백그라운드에서 알림 탭 → 앱 열릴 때
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message, onAnalysisComplete);
    });

    // 8. 앱이 종료된 상태에서 알림 탭으로 앱 실행
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // 약간 지연 후 처리 (라우터 준비 대기)
      await Future.delayed(const Duration(milliseconds: 500));
      _handleNotificationTap(initialMessage, onAnalysisComplete);
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM 권한: ${settings.authorizationStatus}');
  }

  Future<void> _registerToken() async {
    try {
      final token = Platform.isIOS
          ? await _messaging.getAPNSToken().then((_) => _messaging.getToken())
          : await _messaging.getToken();

      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('FCM 토큰 등록 실패: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiClient().post('/api/user/fcm-token', body: {'token': token});
      debugPrint('FCM 토큰 서버 등록 완료');
    } catch (e) {
      debugPrint('FCM 토큰 서버 전송 실패: $e');
    }
  }

  Future<void> _initLocalNotifications({
    required void Function(int sessionId) onAnalysisComplete,
  }) async {
    // Android 채널 생성
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 초기화 설정
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // 로컬 알림 탭 처리
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            final sessionId = int.tryParse(data['sessionId']?.toString() ?? '');
            if (sessionId != null) onAnalysisComplete(sessionId);
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: const Color(0xFF0F3460),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title ?? '미리톡',
      notification.body ?? '분석이 완료됐습니다.',
      details,
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(
      RemoteMessage message,
      void Function(int sessionId) onAnalysisComplete,
      ) {
    final sessionIdStr = message.data['sessionId']?.toString();
    final sessionId = int.tryParse(sessionIdStr ?? '');
    if (sessionId != null) {
      onAnalysisComplete(sessionId);
    }
  }
}