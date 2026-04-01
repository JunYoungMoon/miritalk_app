// // lib/core/ads/banner_ad_widget.dart
// import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'ad_manager.dart';
//
// class BannerAdWidget extends StatefulWidget {
//   const BannerAdWidget({super.key});
//
//   @override
//   State<BannerAdWidget> createState() => _BannerAdWidgetState();
// }
//
// class _BannerAdWidgetState extends State<BannerAdWidget> {
//   BannerAd? _bannerAd;
//   bool _isLoaded = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _bannerAd = BannerAd(
//       adUnitId: AdManager.bannerUnitId,
//       size: AdSize.banner,
//       request: const AdRequest(),
//       listener: BannerAdListener(
//         onAdLoaded: (_) {
//           if (mounted) setState(() => _isLoaded = true);
//         },
//         onAdFailedToLoad: (ad, error) {
//           ad.dispose();
//           _bannerAd = null;
//         },
//       ),
//     )..load();
//   }
//
//   @override
//   void dispose() {
//     _bannerAd?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // 광고 로드 전후 동일한 높이 유지
//     return SafeArea(
//       child: SizedBox(
//         height: AdSize.banner.height.toDouble(), // 항상 50px 확보
//         width: double.infinity,
//         child: _isLoaded && _bannerAd != null
//             ? AdWidget(ad: _bannerAd!)
//             : const SizedBox.shrink(), // 로드 전엔 빈 공간만
//       ),
//     );
//   }
// }

// lib/core/ads/banner_ad_widget.dart
// TODO: google_mobile_ads 추가 후 복구
import 'package:flutter/material.dart';

class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // 광고 자리 비워둠
  }
}