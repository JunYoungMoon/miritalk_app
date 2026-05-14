// lib/features/notification_guard/notification_guard_provider.dart
import 'package:flutter/foundation.dart';
import 'package:miritalk_app/features/notification_guard/services/notification_guard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 사전 차단 설정 화면용 ChangeNotifier.
///
/// UI 가 옵저빙하는 상태:
///   - enabled       : 사용자가 토글로 켰는지 (SharedPreferences `notification_guard_enabled`)
///   - permissionGranted : OS 의 NotificationListener 권한 보유 여부
///   - running       : 실제로 리스너가 바인딩되어 동작 중인지
///
/// permissionGranted 와 enabled 가 모두 true 여야 running 이 true.
class NotificationGuardProvider extends ChangeNotifier {
  bool _enabled = false;
  bool _permissionGranted = false;
  bool _loading = false;

  bool get enabled => _enabled;
  bool get permissionGranted => _permissionGranted;
  bool get loading => _loading;
  bool get running => NotificationGuardService.instance.isRunning;

  Future<void> refresh() async {
    _enabled = await NotificationGuardService.instance.isEnabled();
    _permissionGranted = await NotificationGuardService.instance.isPermissionGranted();

    // 권한이 ON 인데 사용자가 한 번도 명시적으로 토글한 적 없으면 자동 활성화.
    // (OS 설정에서 사용자가 직접 권한 ON 한 경우도 커버) 명시적 disable() 한
    // 적이 있으면 SharedPreferences 에 false 가 저장돼 있으니 이 분기는 안 탄다.
    if (_permissionGranted && !_enabled) {
      final prefs = await SharedPreferences.getInstance();
      final everToggled = prefs.containsKey('notification_guard_enabled');
      if (!everToggled) {
        await NotificationGuardService.instance.enable();
        _enabled = true;
      }
    }
    notifyListeners();
  }

  /// 토글 ON — 권한이 없으면 먼저 OS 설정 페이지로 보낸 뒤 권한 받으면 enable.
  Future<void> requestEnable() async {
    _loading = true;
    notifyListeners();
    try {
      _permissionGranted = await NotificationGuardService.instance.isPermissionGranted();
      if (!_permissionGranted) {
        _permissionGranted = await NotificationGuardService.instance.requestPermission();
      }
      if (_permissionGranted) {
        await NotificationGuardService.instance.enable();
        _enabled = true;
      } else {
        _enabled = false;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> disable() async {
    _loading = true;
    notifyListeners();
    try {
      await NotificationGuardService.instance.disable();
      _enabled = false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
