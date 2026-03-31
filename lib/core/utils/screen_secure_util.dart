// lib/core/utils/screen_secure_util.dart

import 'dart:io';
import 'package:flutter/services.dart';

class ScreenSecureUtil {
  static const _channel = MethodChannel('com.miritalk/window_secure');

  /// Android 전용 FLAG_SECURE 활성화
  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {}
  }

  /// Android 전용 FLAG_SECURE 해제
  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }
}