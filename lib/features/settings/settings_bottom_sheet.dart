// lib/features/settings/settings_bottom_sheet.dart — 전체
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/auth_service.dart';
import 'package:miritalk_app/features/home/conversation_provider.dart';

class SettingsBottomSheet extends StatelessWidget {
  const SettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const SettingsBottomSheet(),
    );
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
                        ? NetworkImage(auth.profileImageUrl!)
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
            _SettingsTile(
              icon: Icons.logout,
              iconColor: AppTheme.textSecondary,
              label: '로그아웃',
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(label,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
      trailing:
      const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 18),
      onTap: onTap,
    );
  }
}