// lib/core/ads/banner_ad_widget.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_manager.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return; // iOS는 현재 광고 미사용

    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerUnitId,
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
