import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/notification_guard/notification_guard_provider.dart';
import 'package:provider/provider.dart';

/// 알림 사기 사전 차단 설정 화면.
///
/// - Android 전용. iOS 진입 시엔 안내 메시지만 노출.
/// - 권한 + 기능 토글, 작동 원리/프라이버시 안내.
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
            const SizedBox(height: 24),
            _howItWorksCard(),
            const SizedBox(height: 16),
            _privacyCard(),
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
            '카카오톡·문자 등의 알림 텍스트를 위험 키워드 사전과 매칭해, '
            '의심 신호가 누적되면 AI 가 판정한 뒤 경고 알림을 보냅니다.',
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

  Widget _howItWorksCard() {
    return _infoCard(
      title: '어떻게 동작하나요',
      bullets: const [
        '서버에서 받은 위험 키워드 사전을 기기에 저장해, 알림이 올 때마다 로컬에서 먼저 점수를 매깁니다.',
        '점수가 임계값을 넘은 알림만 서버로 전송해 AI 가 한 번 더 판정합니다.',
        '여러 알림으로 쪼개져 오는 메시지도 같은 대화방 기준으로 모아서 평가합니다.',
        '의심으로 판정되면 휴대폰에 경고 알림이 즉시 뜹니다.',
      ],
    );
  }

  Widget _privacyCard() {
    return _infoCard(
      title: '프라이버시',
      bullets: const [
        '알림 텍스트는 임계값을 넘은 경우에만 서버로 전송됩니다.',
        '서버는 전송된 텍스트에서 전화번호·계좌·주민번호 패턴을 마스킹한 뒤 분석에만 사용합니다.',
        '발신자/대화방 이름은 SHA-256 해시로만 저장됩니다.',
        '학습용으로 사용하지 않습니다. SAFE 로 판정된 알림은 저장되지 않습니다.',
      ],
    );
  }

  Widget _infoCard({required String title, required List<String> bullets}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, color: AppTheme.primary, size: 5),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
