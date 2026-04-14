// lib/core/update/update_dialog.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class UpdateDialog extends StatelessWidget {
  final bool forceUpdate;
  final String latestVersion;
  final String storeUrl;

  const UpdateDialog({
    super.key,
    required this.forceUpdate,
    required this.latestVersion,
    required this.storeUrl,
  });

  static Future<void> show(
      BuildContext context, {
        required bool forceUpdate,
        required String latestVersion,
        required String storeUrl,
      }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // 강제/선택 모두 바깥 탭 차단
      builder: (_) => UpdateDialog(
        forceUpdate: forceUpdate,
        latestVersion: latestVersion,
        storeUrl: storeUrl,
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 강제 업데이트 시 뒤로가기 차단
      canPop: !forceUpdate,
      child: AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              forceUpdate ? Icons.system_update : Icons.update,
              color: forceUpdate ? AppTheme.danger : AppTheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              forceUpdate ? '업데이트 필요' : '새 버전 출시',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          forceUpdate
              ? '서비스 이용을 위해 최신 버전($latestVersion)으로\n업데이트가 필요합니다.'
              : '새 버전($latestVersion)이 출시되었습니다.\n지금 업데이트하시겠습니까?',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('나중에', style: TextStyle(color: AppTheme.textHint)),
            ),
          if (storeUrl.isNotEmpty)
            ElevatedButton(
              onPressed: _openStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: forceUpdate ? AppTheme.danger : AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('업데이트', style: TextStyle(color: AppTheme.textPrimary)),
            ),
        ],
      ),
    );
  }
}