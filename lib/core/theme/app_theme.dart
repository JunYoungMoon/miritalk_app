// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── 다크 모드 색상 ─────────────────────────────
  static const Color background     = Color(0xFF1A1A2E);
  static const Color surface        = Color(0xFF16213E);
  static const Color surfaceDeep    = Color(0xFF0F3460);
  static const Color primary        = Color(0xFF4FC3F7); // 공통
  static const Color success        = Color(0xFF4CAF50); // 공통
  static const Color danger         = Color(0xFFEF5350); // 공통
  static const Color textPrimary    = Colors.white;
  static const Color textSecondary  = Colors.white60;
  static const Color textHint       = Colors.white38;
  static const Color divider        = Colors.white12;

  // ── 라이트 모드 색상 ───────────────────────────
  static const Color lightBackground  = Color(0xFFF5F7FA);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightSurfaceDeep = Color(0xFFE8F4FD);
  static const Color lightTextPrimary    = Color(0xFF1A1A2E);
  static const Color lightTextSecondary  = Color(0xFF5A6070);
  static const Color lightTextHint       = Color(0xFF9AA0AD);
  static const Color lightDivider        = Color(0xFFE0E0E0);

  // ── ThemeData ──────────────────────────────────
  static ThemeData get dark {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          elevation: 0,
        ),
      ),
      textTheme: GoogleFonts.notoSansKrTextTheme(
        ThemeData.dark().textTheme,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surface,
        error: danger,
      ),
    );
  }

  // app_theme.dart에 light 테마 추가
  static ThemeData get light {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A2E),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
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
      textTheme: GoogleFonts.notoSansKrTextTheme(
        ThemeData.light().textTheme,
      ),
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: Colors.white,
        error: danger,
      ),
    );
  }

  // ── 공통 BoxDecoration ─────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withValues(alpha:0.07)),
  );

  static BoxDecoration get cardDeepDecoration => BoxDecoration(
    gradient: const LinearGradient(
      colors: [surfaceDeep, surface],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: primary.withValues(alpha:0.3)),
  );

  static BoxDecoration primaryBadgeDecoration() => BoxDecoration(
    color: primary.withValues(alpha:0.15),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: primary.withValues(alpha:0.4)),
  );

  static BoxDecoration successBadgeDecoration() => BoxDecoration(
    color: success.withValues(alpha:0.15),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: success.withValues(alpha:0.4)),
  );

  // ── 공통 TextStyle ─────────────────────────────
  static const TextStyle headingStyle = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.4,
  );

  static const TextStyle subHeadingStyle = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: textSecondary,
    fontSize: 13,
    height: 1.6,
  );

  static const TextStyle captionStyle = TextStyle(
    color: textHint,
    fontSize: 12,
    height: 1.4,
  );

  static const TextStyle badgePrimaryStyle = TextStyle(
    color: primary,
    fontSize: 11,
  );

  static const TextStyle badgeSuccessStyle = TextStyle(
    color: success,
    fontSize: 11,
  );
}