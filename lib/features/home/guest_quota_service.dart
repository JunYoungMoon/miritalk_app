// lib/features/home/guest_quota_service.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class GuestQuotaService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Android ID 반환 (Android 전용, 그 외 플랫폼은 null)
  static Future<String?> getAndroidId() async {
    if (!Platform.isAndroid) return null;
    try {
      final android = await _deviceInfo.androidInfo;
      return android.id; // Android ID
    } catch (_) {
      return null;
    }
  }
}