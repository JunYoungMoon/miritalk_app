// lib/features/consent/consent_dialog.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'consent_service.dart';

class ConsentDialog extends StatefulWidget {
  const ConsentDialog({super.key});

  /// 동의가 필요하면 다이얼로그를 띄우고, 이미 동의했으면 바로 true 반환
  static Future<bool> ensureConsent(BuildContext context) async {
    final already = await ConsentService.instance.isConsentGiven();
    if (already) return true;
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );
    return result ?? false;
  }

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _isSaving = false;

  Future<void> _onAgree() async {
    setState(() => _isSaving = true);
    await ConsentService.instance.giveConsent();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('정보 제공 동의',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        ],
      ),
      content: const Text(
        '사기 분석을 위해 업로드하신 대화 내용이 서버로 전송됩니다.\n\n'
            '전송된 데이터는 사기 패턴 분석 목적으로만 사용되며, '
            '분석을 위해 AI 서비스가 활용됩니다. '
            '업로드하신 데이터는 AI 학습에 사용되지 않습니다.\n\n'
            '동의하시면 분석이 시작됩니다.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 1.7,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('거부',
              style: TextStyle(color: AppTheme.textHint)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _onAgree,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Text('동의',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              )),
        ),
      ],
    );
  }
}