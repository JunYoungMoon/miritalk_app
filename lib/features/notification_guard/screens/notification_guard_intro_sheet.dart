import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/notification_guard/notification_guard_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 첫 실행 시 사용자에게 알림 사전 차단 기능을 권유하는 모달 시트.
///
/// 표시 조건 (전부 만족 시):
///   - Android (iOS 미지원)
///   - 권한 미부여 상태 (이미 켜져 있으면 보여줄 필요 없음)
///   - 이전에 보여준 적 없음 (`notification_guard_intro_shown` flag)
///
/// 한 번 보여준 뒤엔 다시 안 뜸. 사용자가 나중에 켜고 싶으면
/// 설정 → 사기 알림 사전 차단 으로 직접 진입.
class NotificationGuardIntroSheet extends StatelessWidget {
  const NotificationGuardIntroSheet({super.key});

  static const String _kShownKey = 'notification_guard_intro_shown';

  /// 조건 충족 시 모달 시트 1회 노출. 호출자는 await 안 해도 됨.
  static Future<void> maybeShow(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kShownKey) == true) return;

    if (!context.mounted) return;
    final provider = context.read<NotificationGuardProvider>();
    await provider.refresh();
    if (provider.permissionGranted) {
      // 이미 권한이 있다면 안내할 필요 없음 — flag 만 세워두고 종료
      await prefs.setBool(_kShownKey, true);
      return;
    }

    if (!context.mounted) return;

    // 짧은 지연 — 다른 다이얼로그(업데이트 등) 와 겹치지 않도록.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const NotificationGuardIntroSheet(),
    );

    // 노출했으면 flag 세팅 — 사용자가 어떤 선택을 했든 다시 안 보여줌.
    await prefs.setBool(_kShownKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Hero
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '사기 알림을\n사전에 차단해드릴까요?',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Text(
              '카카오톡·문자로 들어오는 의심 알림을 미리톡이 먼저 읽어 사기 패턴을 잡아내고, '
              '실제 사기로 판정되면 즉시 경고해드립니다.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),

            _bullet('의심 알림은 AI 가 한 번 더 검증 — 오발화 최소화'),
            _bullet('학습용으로 사용하지 않음 · 개인정보는 마스킹'),
            _bullet('언제든 설정에서 끌 수 있어요'),

            const SizedBox(height: 24),

            // Primary CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: () async {
                  // 시트는 먼저 닫고 권한 요청 (OS 페이지가 위에 떠야 자연스러움)
                  Navigator.pop(context);
                  await context.read<NotificationGuardProvider>().requestEnable();
                  // requestEnable 내부에서 권한 페이지 다녀와서 상태 갱신.
                },
                child: const Text('지금 켜기'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('나중에 켤게요'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.check_circle, color: AppTheme.primary, size: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
