// lib/features/analysis/mixpanel_service.dart
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:miritalk_app/core/config/app_config.dart';

class MixpanelService {
  MixpanelService._();
  static final MixpanelService instance = MixpanelService._();

  Mixpanel? _mixpanel;

  Future<void> initialize() async {
    _mixpanel = await Mixpanel.init(
      AppConfig.mixpanelToken,
      trackAutomaticEvents: true,
    );
  }

  void logScreenTime({
    required String screenName,
    required int durationSeconds,
  }) {
    _mixpanel?.track('screen_time', properties: {
      'screen_name': screenName,
      'duration_seconds': durationSeconds,
    });
  }

  void logEvent(String name, {Map<String, dynamic>? properties}) {
    _mixpanel?.track(name, properties: properties);
  }
}