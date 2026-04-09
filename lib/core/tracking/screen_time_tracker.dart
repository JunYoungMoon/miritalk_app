// lib/core/tracking/screen_time_tracker.dart
import 'package:miritalk_app/core/tracking/mixpanel_service.dart';

class ScreenTimeTracker {
  final String screenName;
  final DateTime _enterTime = DateTime.now();

  ScreenTimeTracker(this.screenName);

  void dispose() {
    final seconds = DateTime.now().difference(_enterTime).inSeconds;
    // Mixpanel 전송
    MixpanelService.instance.logScreenTime(
      screenName: screenName,
      durationSeconds: seconds,
    );
  }
}