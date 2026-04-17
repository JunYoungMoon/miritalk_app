// lib/core/notifications/fcm_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:miritalk_app/firebase_options.dart';

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

  static const String _channelId = 'miritalk_analysis';
  static const String _channelName = '분석 완료 알림';
  static const String _channelDesc = '사기 분석이 완료되면 알림을 보냅니다.';

  Future<void> initialize({
    // ← 시그니처 변경: imageToken 추가
    required void Function(int sessionId, String? imageToken) onAnalysisComplete,
  }) async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initLocalNotifications(onAnalysisComplete: onAnalysisComplete);
    await _requestPermission();
    await _registerToken();
    _messaging.onTokenRefresh.listen(_sendTokenToServer);

    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message, onAnalysisComplete);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
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
      if (token != null) await _sendTokenToServer(token);
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
    required void Function(int sessionId, String? imageToken) onAnalysisComplete,
  }) async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

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
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            final sessionId = int.tryParse(data['sessionId']?.toString() ?? '');
            final imageToken = data['imageToken']?.toString();
            if (sessionId != null) onAnalysisComplete(sessionId, imageToken);
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

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title ?? '미리톡',
      notification.body ?? '분석이 완료됐습니다.',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),  // imageToken이 data에 있으면 자동 포함
    );
  }

  void _handleNotificationTap(
      RemoteMessage message,
      void Function(int sessionId, String? imageToken) onAnalysisComplete,
      ) {
    final sessionId = int.tryParse(message.data['sessionId']?.toString() ?? '');
    final imageToken = message.data['imageToken']?.toString();
    if (sessionId != null) {
      onAnalysisComplete(sessionId, imageToken);
    }
  }
}