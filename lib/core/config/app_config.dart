// lib/core/config/app_config.dart
class AppConfig {
  AppConfig._();

  static const String baseUrl = 'https://miri.sweepfn.org';
  static const String tokenKey = 'access_token';
  static const int maxImages = 5;
  static const String androidClientID = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
}