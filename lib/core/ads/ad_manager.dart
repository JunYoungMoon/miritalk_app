// lib/core/ads/ad_manager.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config_provider.dart';

/// 광고 위치 키. 백엔드 ad_placement.placement_key 와 1:1 매칭.
class AdPlacements {
  AdPlacements._();
  static const String homeBanner = 'home_banner';
  static const String uploadBanner = 'upload_banner';
  static const String resultBanner = 'result_banner';
  static const String communityBanner = 'community_banner';
  static const String analysisDoneInterstitial = 'analysis_done_interstitial';
}

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ── Android 광고 단위 ID — 서버에서 오버라이드 안 줄 때의 빌트인 기본값 ──
  static const String _interstitialUnitIdAndroid =
      'ca-app-pub-7881277177118813/2351293793';
  static const String _bannerUnitIdAndroid =
      'ca-app-pub-7881277177118813/5520382612';

  AdConfigProvider? _config;

  /// main.dart 부트스트랩에서 호출. 이후 AdManager 가 컨피그를 참조한다.
  void attachConfig(AdConfigProvider config) {
    _config = config;
  }

  bool get _adsEnabled => Platform.isAndroid;

  /// 위치별 노출 여부. 컨피그 미수신/플랫폼 미지원 시 기본 동작 유지.
  bool isEnabled(String placementKey) {
    if (!_adsEnabled) return false;
    return _config?.isPlacementEnabled(placementKey) ?? true;
  }

  /// 위치별 배너 광고 단위 ID. 서버 오버라이드 우선, 없으면 빌트인.
  String bannerAdUnitId(String placementKey) {
    if (!Platform.isAndroid) return '';
    return _config?.adUnitIdAndroid(placementKey) ?? _bannerUnitIdAndroid;
  }

  /// 전면광고 단위 ID. analysis_done_interstitial 위치만 사용.
  String _interstitialAdUnitId() {
    if (!Platform.isAndroid) return '';
    return _config?.adUnitIdAndroid(AdPlacements.analysisDoneInterstitial)
        ?? _interstitialUnitIdAndroid;
  }

  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  /// 전면광고를 미리 로드해 둡니다. (Android에서만 동작)
  /// 위치가 비활성화된 경우 로드 자체를 건너뜁니다.
  void loadInterstitial() {
    if (!_adsEnabled || _isLoaded || _isLoading) return;
    if (!isEnabled(AdPlacements.analysisDoneInterstitial)) return;

    _isLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId(),
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
  /// [placementKey] 의 frequency_cap 이 N(>1)이면 N번 호출당 1회만 노출.
  Future<void> showInterstitial({
    String placementKey = AdPlacements.analysisDoneInterstitial,
    required VoidCallback onClosed,
  }) async {
    if (!isEnabled(placementKey)) {
      onClosed();
      return;
    }

    final cap = _config?.frequencyCap(placementKey) ?? 1;
    if (cap > 1) {
      final shouldShow = await _consumeFrequencyCap(placementKey, cap);
      if (!shouldShow) {
        onClosed();
        return;
      }
    }

    if (!_isLoaded || _interstitialAd == null) {
      loadInterstitial(); // 다음 기회를 위해 미리 받아둠
      onClosed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isLoaded = false;
        // navigation 먼저, 다음 광고 prefetch 는 그 뒤로 — 결과화면 진입 지연 방지
        onClosed();
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isLoaded = false;
        onClosed();
        loadInterstitial();
      },
    );

    _interstitialAd!.show();
  }

  /// frequency_cap 카운터. cap 의 배수일 때만 true 반환.
  /// 카운터는 SharedPreferences 에 영속화 — 앱 재시작에도 유지된다.
  Future<bool> _consumeFrequencyCap(String placementKey, int cap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'ad_freq_$placementKey';
      final next = (prefs.getInt(key) ?? 0) + 1;
      if (next >= cap) {
        await prefs.setInt(key, 0);
        return true;
      } else {
        await prefs.setInt(key, next);
        return false;
      }
    } catch (e) {
      debugPrint('frequency_cap 처리 실패 — 기본 노출 허용: $e');
      return true;
    }
  }

  /// 다음 화면을 위해 미리 재로드합니다.
  void preload() => loadInterstitial();
}
