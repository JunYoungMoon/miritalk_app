// lib/core/ads/ad_manager.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ── Android 광고 단위 ID ──
  static const String _interstitialUnitIdAndroid =
      'ca-app-pub-7881277177118813/2351293793';
  static const String _bannerUnitIdAndroid =
      'ca-app-pub-7881277177118813/5520382612';

  // iOS는 현재 광고 미사용 — 빈 문자열이면 호출부에서 자동으로 no-op
  static String get bannerUnitId =>
      Platform.isAndroid ? _bannerUnitIdAndroid : '';
  static String get _interstitialUnitId =>
      Platform.isAndroid ? _interstitialUnitIdAndroid : '';

  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get _adsEnabled => Platform.isAndroid;

  /// 전면광고를 미리 로드해 둡니다. (Android에서만 동작)
  void loadInterstitial() {
    if (!_adsEnabled || _isLoaded || _isLoading) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoaded = true;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd 로드 실패: $error');
          _interstitialAd = null;
          _isLoaded = false;
          _isLoading = false;
        },
      ),
    );
  }

  /// 전면광고를 표시하고, 닫히면 [onClosed]를 호출합니다.
  /// 광고가 없거나 실패해도 [onClosed]는 반드시 호출됩니다.
  void showInterstitial({required VoidCallback onClosed}) {
    if (!_adsEnabled || !_isLoaded || _interstitialAd == null) {
      // 다음 기회를 위해 미리 받아둠
      loadInterstitial();
      onClosed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isLoaded = false;
        loadInterstitial(); // 다음 노출을 위해 재로드
        onClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isLoaded = false;
        loadInterstitial();
        onClosed();
      },
    );

    _interstitialAd!.show();
  }

  /// 다음 화면을 위해 미리 재로드합니다.
  void preload() => loadInterstitial();
}
