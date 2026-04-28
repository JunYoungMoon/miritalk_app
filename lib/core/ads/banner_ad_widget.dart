// lib/core/ads/banner_ad_widget.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'ad_config_provider.dart';
import 'ad_manager.dart';

/// 위치별 배너 광고. [placementKey] 는 백엔드 ad_placement.placement_key 와 매칭.
/// 서버 컨피그가 비활성이면 SizedBox.shrink (높이 0). 활성이면 50px 배너.
class BannerAdWidget extends StatefulWidget {
  final String placementKey;

  const BannerAdWidget({super.key, required this.placementKey});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isInitialized = false;

  void _initAd() {
    if (_isInitialized) return;
    if (!Platform.isAndroid) return;
    _isInitialized = true;

    _bannerAd = BannerAd(
      adUnitId: AdManager.instance.bannerAdUnitId(widget.placementKey),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    // 컨피그가 갱신되면 enabled 가 바뀔 수 있으므로 watch
    final enabled = context
        .watch<AdConfigProvider>()
        .isPlacementEnabled(widget.placementKey);

    if (!enabled) return const SizedBox.shrink();

    // 활성화 상태에서 최초 빌드 시점에 광고 로드 시작
    _initAd();

    // 광고 로드 전후 동일한 높이 유지 (50px 항상 확보)
    return SafeArea(
      top: false,
      child: SizedBox(
        height: AdSize.banner.height.toDouble(),
        width: double.infinity,
        child: _isLoaded && _bannerAd != null
            ? AdWidget(ad: _bannerAd!)
            : const SizedBox.shrink(),
      ),
    );
  }
}
