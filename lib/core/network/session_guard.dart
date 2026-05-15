// lib/core/network/session_guard.dart
//
// 핵심 액션(분석 시작, 히스토리 진입 등) 직전에 세션을 사전 검증하고,
// 만료된 경우 통일된 다이얼로그 + 로그인 화면 라우팅 + **자동 복귀** 까지 처리한다.
//
// 자동 복귀 흐름:
//   1) 만료 감지 → 다이얼로그 → LoginScreen push(await)
//   2) LoginScreen 이 닫히면 (로그인 성공이면 _handleLogin 의 Navigator.pop, 취소면 close 버튼)
//      AuthProvider.isLoggedIn 으로 결과 판정.
//   3) 새로 로그인됐으면 true 반환 → 호출자가 그 자리에서 원래 액션을 이어 실행한다.
//      취소됐으면 false 반환 → 호출자는 진행 중단.
//
// 호출 예:
// ```dart
// if (auth.isLoggedIn) {
//   if (!await ensureSessionOrPrompt(context)) return;
// }
// // 이후 실제 액션 진행 — 만료 → 로그인 성공 케이스도 여기로 자연스럽게 흐른다.
// ```
//
// 게스트는 호출 측에서 isLoggedIn 분기로 스킵하는 것이 권장 — ensureSession 자체가
// 게스트는 통과시키지만, 굳이 호출할 필요 없는 자명한 케이스다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';

// 진행 중인 가드의 Future. 여러 진입점이 동시에 호출돼도 다이얼로그/로그인 화면이
// 한 번만 뜨도록 single-flight 로 합친다. 동일 흐름의 다중 탭(프로필 아바타 빠른 연타 등)에서
// "세션 만료" 다이얼로그가 중첩 출현하거나 LoginScreen 이 여러 장 stack 되는 현상을 막는다.
Future<bool>? _inFlight;

Future<bool> ensureSessionOrPrompt(BuildContext context) async {
  final existing = _inFlight;
  if (existing != null) {
    final result = await existing;
    if (!context.mounted) return false;
    return result;
  }
  final task = _runEnsure(context);
  _inFlight = task;
  try {
    return await task;
  } finally {
    _inFlight = null;
  }
}

Future<bool> _runEnsure(BuildContext context) async {
  try {
    await ApiClient().ensureSession();
    return true;
  } on UnauthorizedException {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: AppTheme.danger, size: 20),
            SizedBox(width: 8),
            Text(
              '세션이 만료되었습니다',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          '보안을 위해 다시 로그인해주세요.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    if (!context.mounted) return false;
    // LoginScreen 은 root navigator 에 push — 모달/시트 위에서 가드가 발동해도
    // 루트 라우트로 띄워져 시트 dispose 와 무관하게 동작한다. 닫힐 때까지 await.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    await rootNavigator.push<void>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!context.mounted) return false;
    // 새로 로그인됐으면 true → 호출자가 원래 액션을 이어 실행. 취소됐으면 false.
    return context.read<AuthProvider>().isLoggedIn;
  }
}
