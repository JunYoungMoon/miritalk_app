// lib/features/settings/settings_bottom_sheet.dart — 전체
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'dart:io' show Platform;
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/auth_service.dart';
import 'package:miritalk_app/features/home/conversation_provider.dart';
import 'package:miritalk_app/features/notification_guard/screens/notification_guard_settings_screen.dart';

class SettingsBottomSheet extends StatelessWidget {
  const SettingsBottomSheet({super.key});

  // 시트가 이미 떠 있는 동안 show() 가 다시 호출돼도 한 장만 띄운다.
  // 호출자(프로필 아바타 탭 등)의 다중 진입을 시트 레이어에서 한 번 더 방어.
  static Future<void>? _inFlight;

  static Future<void> show(BuildContext context) {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const SettingsBottomSheet(),
    );
    _inFlight = future;
    return future.whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _onWithdraw(BuildContext context) async {
    // ── 바텀시트를 먼저 닫지 말고 다이얼로그 먼저 띄우기 ──
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
            SizedBox(width: 8),
            Text('회원 탈퇴',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: const Text(
          '탈퇴하시면 모든 분석 내역과 계정 정보가\n영구적으로 삭제됩니다.\n\n정말 탈퇴하시겠습니까?',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴하기',
                style: TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // ── 다이얼로그 확인 후 바텀시트 닫기 ──
    if (context.mounted) Navigator.pop(context);

    // ── 탈퇴 API 호출 ──
    // context가 무효화될 수 있으므로 미리 provider 참조 저장
    final authProvider = context.read<AuthProvider>();
    final conversationProvider = context.read<ConversationProvider>();

    final result = await authProvider.withdraw();
    if (!context.mounted) return;

    switch (result) {
      case WithdrawResult.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('탈퇴가 완료되었습니다.'),
            backgroundColor: AppTheme.surface,
          ),
        );
      case WithdrawResult.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계정 정보를 찾을 수 없습니다. 다시 로그인 해주세요.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      case WithdrawResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
            backgroundColor: AppTheme.danger,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isWithdrawing = auth.isWithdrawing;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('설정',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDeep,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.surface,
                    backgroundImage: auth.profileImageUrl != null
                        ? ResizeImage(NetworkImage(auth.profileImageUrl!),
                            width: 96)
                        : null,
                    child: auth.profileImageUrl == null
                        ? const Icon(Icons.person,
                        color: AppTheme.primary, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.userName ?? '사용자',
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(auth.userEmail ?? '',
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 8),
            if (Platform.isAndroid)
              _SettingsTile(
                icon: Icons.shield_outlined,
                iconColor: AppTheme.primary,
                label: '사기 알림 사전 차단',
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationGuardSettingsScreen(),
                  ));
                },
              ),
            _SettingsTile(
              icon: Icons.logout,
              iconColor: AppTheme.textSecondary,
              label: '로그아웃',
              onTap: () async {
                // 시트 pop 으로 context 가 dispose 되기 전에 provider 를 미리 캡처.
                final auth = context.read<AuthProvider>();
                Navigator.pop(context);
                await auth.logout();
              },
            ),
            const SizedBox(height: 32),
            Center(
              child: isWithdrawing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.textHint),
              )
                  : TextButton(
                onPressed: () => _onWithdraw(context),
                child: const Text(
                  '회원 탈퇴',
                  style: TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.textHint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  // 시그니처를 `Future<void> Function()` 으로 받아 await + try/finally 로
  // 빠른 다중 탭을 안전하게 가드한다. 호출자는 sync 함수도 그대로 넘길 수 있다(async 래핑 시).
  final Future<void> Function() onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  // 빠른 다중 탭 시 onTap 안의 Navigator.pop + push 가 N번 실행되어
  // 같은 화면이 stack 되는 현상을 막는다. 회원 탈퇴 다이얼로그 취소처럼
  // 시트가 닫히지 않는 경로가 있어 try/finally + setState 로 안전하게 복구한다.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(widget.icon, color: widget.iconColor, size: 20),
      title: Text(widget.label,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
      trailing:
      const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 18),
      onTap: () async {
        if (_busy) return;
        setState(() => _busy = true);
        try {
          await widget.onTap();
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}