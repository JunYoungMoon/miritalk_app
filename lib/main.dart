// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'features/auth/auth_provider.dart';
import 'features/home/home_screen.dart';
import 'features/home/conversation_provider.dart';
import 'features/home/analysis_quota_provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
  await MobileAds.instance.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisQuotaProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '미리톡 사기 방지 시스템',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
      },
      // builder 속성을 추가하여 MediaQuery 설정을 덮어씌웁니다.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // 시스템의 글꼴 크기 변경을 무시하고 1.0 배율로 고정합니다.
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}