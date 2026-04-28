// lib/core/ads/ad_config.dart
//
// 서버 `/api/config/ads` 응답을 그대로 반영하는 모델.
// 위치별 노출 여부와 광고 단위 ID 오버라이드, 전면광고 빈도 제한을 담는다.
class AdPlacementConfig {
  final bool enabled;
  final String? adUnitIdAndroid;
  final int? frequencyCap;

  const AdPlacementConfig({
    required this.enabled,
    this.adUnitIdAndroid,
    this.frequencyCap,
  });

  factory AdPlacementConfig.fromJson(Map<String, dynamic> json) {
    return AdPlacementConfig(
      enabled: json['enabled'] as bool? ?? false,
      adUnitIdAndroid: json['adUnitIdAndroid'] as String?,
      frequencyCap: json['frequencyCap'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (adUnitIdAndroid != null) 'adUnitIdAndroid': adUnitIdAndroid,
        if (frequencyCap != null) 'frequencyCap': frequencyCap,
      };
}

class AdConfig {
  final int version;
  final Map<String, AdPlacementConfig> placements;

  const AdConfig({required this.version, required this.placements});

  AdPlacementConfig? placement(String key) => placements[key];

  factory AdConfig.fromJson(Map<String, dynamic> json) {
    final raw = (json['placements'] as Map?) ?? const {};
    final placements = <String, AdPlacementConfig>{};
    raw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        placements[key.toString()] = AdPlacementConfig.fromJson(value);
      }
    });
    // 백엔드는 epoch 초(long) 로 보내므로 int 로 안전 변환
    final v = json['version'];
    final version = v is int ? v : (v is num ? v.toInt() : 0);
    return AdConfig(version: version, placements: placements);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'placements': placements.map((k, v) => MapEntry(k, v.toJson())),
      };
}
