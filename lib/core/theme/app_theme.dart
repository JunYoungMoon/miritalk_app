// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── 다크 모드 배경/서피스 ──────────────────────
  static const Color background  = Color(0xFF0A0A14);  // 더 깊은 블랙-네이비
  static const Color surface     = Color(0xFF11112A);  // 네이비 서피스
  static const Color surfaceDeep = Color(0xFF1A1A3E);  // 포인트 서피스

  // ── 포인트 색상 ────────────────────────────────
  static const Color primary = Color(0xFF9B87F5);      // 퍼플 (기존 스카이블루 → 교체)
  static const Color primaryDeep = Color(0xFF6B4FE8);  // 딥 퍼플 (그라데이션 끝)
  static const Color success = Color(0xFF4DB896);      // 민트 그린
  static const Color danger  = Color(0xFFE05252);      // 소프트 레드
  static const Color warning = Color(0xFFE09C40);      // 앰버

  // ── 텍스트 ────────────────────────────────────
  static const Color textPrimary   = Color(0xFFEEEEFF); // 순백 대신 살짝 보랏빛
  static const Color textSecondary = Color(0xFF9090B0); // 뮤트 퍼플-그레이
  static const Color textHint      = Color(0xFF555570); // 더 어두운 힌트

  // ── 구분선/오버레이 ────────────────────────────
  static const Color divider       = Color(0x1AFFFFFF);
  static const Color dividerLight  = Color(0x33FFFFFF);
  static const Color overlayDark   = Color(0x8C000000);
  static const Color overlayMedium = Color(0x7F000000);
  static const Color overlayLight  = Color(0x99000000);
  static const Color photoLabelBg  = Color(0xCC000000);

  // ── 위험도 색상 ────────────────────────────────
  static const Color riskHigh       = Color(0xFFE05252);
  static const Color riskMedium     = Color(0xFFE09C40);
  static const Color riskLow        = Color(0xFF4DB896);
  static const Color tickerHighBg   = Color(0x1FE05252);
  static const Color tickerMediumBg = Color(0x1AE09C40);

  // ── 카드 보더 (퍼플 틴트) ─────────────────────
  static const Color cardBorder     = Color(0x259B87F5); // primary 15%
  static const Color cardBorderDeep = Color(0x406B4FE8); // primaryDeep 25%

  // ── 라이트 모드 ────────────────────────────────
  static const Color lightBackground    = Color(0xFFF3F3FA);
  static const Color lightSurface       = Color(0xFFFFFFFF);
  static const Color lightSurfaceDeep   = Color(0xFFEEEBFF);
  static const Color lightTextPrimary   = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF5A5A7A);
  static const Color lightTextHint      = Color(0xFF9A9AB0);
  static const Color lightDivider       = Color(0xFFE0E0F0);

  // ── 위험도 유틸 ────────────────────────────────
  static Color riskLevelColor(String level) {
    switch (level) {
      case '매우높음': return danger;
      case '높음':    return warning;
      case '보통':    return Colors.yellow;
      default:        return success;
    }
  }

  static String riskScoreToLevel(int score) {
    if (score >= 80) return '매우높음';
    if (score >= 60) return '높음';
    if (score >= 40) return '보통';
    return '낮음';
  }

  // ── 퍼플 그라데이션 헬퍼 ──────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9B87F5), Color(0xFF6B4FE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF11112A), Color(0xFF1A1A3E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── 시스템 오버레이 (다크 테마, edge-to-edge) ──
  // Android 15 SDK 35의 강제 edge-to-edge 모드에서 시스템바를 투명하게 두고
  // 아이콘은 라이트(다크 배경 위) 로 고정. 매 화면 전환 시 PlatformPlugin
  // 이 동일한 값을 반복 적용하지 않도록 AppBarTheme 에 한 번만 지정한다.
  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  // ── ThemeData: dark ────────────────────────────
  static ThemeData get dark => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      systemOverlayStyle: darkOverlay,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: surface),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        elevation: 0,
      ),
    ),
    textTheme: GoogleFonts.notoSansKrTextTheme(ThemeData.dark().textTheme),
    colorScheme: const ColorScheme.dark(
      primary: primary,
      surface: surface,
      error: danger,
    ),
  );

  // ── ThemeData: light ───────────────────────────
  static ThemeData get light => ThemeData.light().copyWith(
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      elevation: 0,
      iconTheme: IconThemeData(color: lightTextPrimary),
      titleTextStyle: TextStyle(
        color: lightTextPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: lightSurface),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        elevation: 0,
      ),
    ),
    textTheme: GoogleFonts.notoSansKrTextTheme(ThemeData.light().textTheme),
    colorScheme: const ColorScheme.light(
      primary: primary,
      surface: lightSurface,
      error: danger,
    ),
  );

  // ── BoxDecoration 헬퍼 ─────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: cardBorder),
  );

  static BoxDecoration get cardDeepDecoration => BoxDecoration(
    color: surfaceDeep,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cardBorderDeep),
  );

  static BoxDecoration primaryBadgeDecoration() => BoxDecoration(
    color: primary.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: primary.withValues(alpha: 0.3)),
  );

  static BoxDecoration successBadgeDecoration() => BoxDecoration(
    color: success.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: success.withValues(alpha: 0.3)),
  );

  static BoxDecoration dangerBadgeDecoration() => BoxDecoration(
    color: danger.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: danger.withValues(alpha: 0.25)),
  );

  // ── TextStyle 헬퍼 ─────────────────────────────
  static const TextStyle headingStyle = TextStyle(
    color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4,
  );
  static const TextStyle subHeadingStyle = TextStyle(
    color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold,
  );
  static const TextStyle bodyStyle = TextStyle(
    color: textSecondary, fontSize: 13, height: 1.6,
  );
  static const TextStyle captionStyle = TextStyle(
    color: textHint, fontSize: 12, height: 1.4,
  );
  static const TextStyle badgePrimaryStyle = TextStyle(
    color: primary, fontSize: 11,
  );
  static const TextStyle badgeSuccessStyle = TextStyle(
    color: success, fontSize: 11,
  );
}