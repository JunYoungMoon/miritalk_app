// lib/core/ads/ad_manager.dart
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;

  // 테스트 ID — 출시 전 실제 ID로 교체
  static const String _interstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String bannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// 전면광고를 미리 로드해 둡니다.
  void loadInterstitial() {
    if (_isLoaded) return;
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd 로드 실패: $error');
          _interstitialAd = null;
          _isLoaded = false;
        },
      ),
    );
  }

  /// 전면광고를 표시하고, 닫히면 [onClosed]를 호출합니다.
  /// 광고가 없거나 실패해도 [onClosed]는 반드시 호출됩니다.
  void showInterstitial({required VoidCallback onClosed}) {
    if (!_isLoaded || _interstitialAd == null) {
      onClosed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isLoaded = false;
        onClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isLoaded = false;
        onClosed();
      },
    );

    _interstitialAd!.show();
  }

  /// 다음 화면을 위해 미리 재로드합니다.
  void preload() => loadInterstitial();
}