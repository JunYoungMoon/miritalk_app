// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/core/notifications/fcm_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/home/home_screen.dart';
import 'features/home/conversation_provider.dart';
import 'features/home/analysis_quota_provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/analysis/analysis_result_screen.dart';
import 'package:miritalk_app/core/tracking/mixpanel_service.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:miritalk_app/features/inquiry/inquiry_list_screen.dart';
import 'dart:ui';
import 'firebase_options.dart';
import 'package:flutter/services.dart';

// 앱 전역에서 Navigator 접근을 위한 키
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 고정 추가
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Android 15 SDK 35 강제 edge-to-edge 모드 대비:
  // 시스템바를 투명 + 라이트 아이콘으로 고정해 첫 프레임부터 일관된 모습.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.darkOverlay);

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics 설정
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Mixpanel 초기화
  await MixpanelService.instance.initialize();

  KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);

  final conversationProvider = ConversationProvider();
  final authProvider = AuthProvider()
    ..checkLoginStatus()
    ..setConversationProvider(conversationProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => conversationProvider),
        ChangeNotifierProvider(create: (_) => AnalysisQuotaProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 로그인 상태일 때만 FCM 초기화 (토큰 서버 등록 포함)
    // 위젯 트리 빌드 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFcm());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      TrackingService.instance.logAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      TrackingService.instance.logAppResumed();
    }
  }

  Future<void> _initFcm() async {
    await FcmService.instance.initialize(
      onAnalysisComplete: (sessionId, imageToken) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/result',
              (route) => route.settings.name == '/home' || route.isFirst,
          arguments: {'sessionId': sessionId, 'imageToken': imageToken},
        );
      },
      onInquiryReply: () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const InquiryListScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '미리톡 사기 방지 시스템',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/result': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is Map) {
            return AnalysisResultScreen(
              sessionId: args['sessionId'] as int,
              guestImageToken: args['imageToken'] as String?,  // imageToken → guestImageToken
            );
          }
          return AnalysisResultScreen(
            sessionId: args as int,
            guestImageToken: null,
          );
        },
        '/inquiry': (_) => const InquiryListScreen(),
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.2),
          ),
          child: child!,
        );
      },
    );
  }
}