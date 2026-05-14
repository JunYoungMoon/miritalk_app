// lib/features/notification_guard/screens/notification_guard_settings_screen.dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/notification_guard/notification_guard_provider.dart';
import 'package:provider/provider.dart';

/// 알림 사기 사전 차단 설정 화면.
///
/// - Android 전용. iOS 진입 시엔 안내 메시지만 노출.
/// - 권한 + 기능 토글만 노출.
/// - 권한 페이지에서 돌아왔을 때 권한 상태 재확인을 위해 lifecycle 옵저버 사용.
class NotificationGuardSettingsScreen extends StatefulWidget {
  const NotificationGuardSettingsScreen({super.key});

  @override
  State<NotificationGuardSettingsScreen> createState() =>
      _NotificationGuardSettingsScreenState();
}

class _NotificationGuardSettingsScreenState
    extends State<NotificationGuardSettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationGuardProvider>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationGuardProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('사기 알림 사전 차단'),
        elevation: 0,
      ),
      body: Platform.isAndroid ? _androidBody() : _iosBody(),
    );
  }

  Widget _androidBody() {
    return Consumer<NotificationGuardProvider>(
      builder: (context, p, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _heroCard(p),
          ],
        );
      },
    );
  }

  Widget _iosBody() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'iOS 는 OS 정책상 다른 앱의 알림을 읽을 수 없어\n이 기능을 제공하지 못합니다.\n\n'
          '의심되는 대화는 스크린샷을 업로드해 분석해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
        ),
      ),
    );
  }

  Widget _heroCard(NotificationGuardProvider p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '들어오는 알림을 읽어 사기를 사전에 막아드려요',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '카카오톡·문자 등 들어오는 알림에서 사기 의심 신호가 발견되면 '
            '즉시 경고해드립니다.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          _toggleRow(p),
          if (!p.permissionGranted && p.enabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '알림 접근 권한이 꺼져 있어 작동하지 않아요. 토글을 다시 켜서 권한을 허용해 주세요.',
                style: TextStyle(
                  color: AppTheme.warning,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toggleRow(NotificationGuardProvider p) {
    final disabled = p.loading;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.running ? '동작 중' : '꺼짐',
                style: TextStyle(
                  color: p.running ? AppTheme.success : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.running ? '의심 알림이 도착하면 경고를 보냅니다' : '사기 알림 사전 차단을 시작하려면 켜 주세요',
                style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: p.enabled,
          activeThumbColor: AppTheme.primary,
          onChanged: disabled
              ? null
              : (v) async {
                  if (v) {
                    await p.requestEnable();
                  } else {
                    await p.disable();
                  }
                },
        ),
      ],
    );
  }

}
