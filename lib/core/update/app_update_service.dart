// lib/core/update/app_update_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:miritalk_app/core/network/api_client.dart';

class VersionCheckResult {
  final bool forceUpdate;
  final bool optionalUpdate;
  final String latestVersion;
  final String storeUrl;

  const VersionCheckResult({
    required this.forceUpdate,
    required this.optionalUpdate,
    required this.latestVersion,
    required this.storeUrl,
  });
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  Future<VersionCheckResult?> checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';

      final response = await ApiClient().get(
        '/api/version?current=${info.version}&platform=$platform',
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return VersionCheckResult(
        forceUpdate: json['forceUpdate'] as bool,
        optionalUpdate: json['optionalUpdate'] as bool,
        latestVersion: json['latestVersion'] as String,
        storeUrl: json['storeUrl'] as String,
      );
    } catch (_) {
      return null; // 체크 실패 시 그냥 통과
    }
  }
}