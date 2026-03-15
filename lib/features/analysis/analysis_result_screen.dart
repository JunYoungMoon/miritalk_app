// lib/features/analysis/analysis_result_screen.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class ChatMessage {
  final String type;
  final String text;
  final bool isDone;

  const ChatMessage({
    required this.type,
    required this.text,
    this.isDone = false,
  });

  ChatMessage copyWith({String? text, bool? isDone}) {
    return ChatMessage(
      type: type,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
    );
  }
}

class AnalysisResultScreen extends StatelessWidget {
  final List<ChatMessage> messages;
  const AnalysisResultScreen({super.key, required this.messages});

  // 메시지 목록에서 특정 타입 텍스트 추출
  String _findText(String type) {
    try {
      return messages.firstWhere((m) => m.type == type).text;
    } catch (_) {
      return '';
    }
  }

  Color _riskColor(String level) {
    switch (level) {
      case '매우높음': return AppTheme.danger;
      case '높음':    return Colors.orange;
      case '보통':    return Colors.yellow;
      default:        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskLevel = _findText('riskLevel');
    final riskScore = _findText('riskScore');
    final riskColor = _riskColor(riskLevel);

    // 결과 화면에서 stream 타입은 숨김 (parseAndSendResult로 구조화된 타입만 표시)
    final displayMessages = messages
        .where((m) => m.type != 'stream' && m.type != 'riskLevel' && m.type != 'riskScore')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          color: AppTheme.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '분석 결과',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          // ── 위험도 헤더 카드 ──────────────────────
          _RiskHeaderCard(
            riskLevel: riskLevel,
            riskScore: riskScore,
            riskColor: riskColor,
          ),
          const SizedBox(height: 8),

          // ── 분석 결과 카드들 ──────────────────────
          ...displayMessages.map((m) => _ChatBubble(message: m)),
        ],
      ),
    );
  }
}

// ── 위험도 헤더 카드 ────────────────────────────────
class _RiskHeaderCard extends StatelessWidget {
  final String riskLevel;
  final String riskScore;
  final Color riskColor;

  const _RiskHeaderCard({
    required this.riskLevel,
    required this.riskScore,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(riskScore) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            riskColor.withValues(alpha: 0.2),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '사기 위험도',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    riskLevel.isEmpty ? '분석 중' : riskLevel,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // 원형 점수 표시
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 6,
                      backgroundColor: AppTheme.surfaceDeep,
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                    ),
                  ),
                  Text(
                    '$score%',
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 점수 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceDeep,
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 분석 결과 버블 ──────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  IconData get _icon {
    switch (message.type) {
      case 'summary':   return Icons.smart_toy_outlined;
      case 'suspicious':return Icons.search_rounded;
      case 'action':    return Icons.tips_and_updates_outlined;
      case 'questions': return Icons.help_outline_rounded;
      case 'raw':       return Icons.article_outlined;
      default:          return Icons.info_outline;
    }
  }

  Color get _color {
    switch (message.type) {
      case 'suspicious':return Colors.orange;
      case 'action':    return AppTheme.success;
      case 'questions': return Colors.blue;
      default:          return AppTheme.primary;
    }
  }

  String get _label {
    switch (message.type) {
      case 'summary':   return '종합 분석';
      case 'suspicious':return '의심 포인트';
      case 'action':    return '권장 행동';
      case 'questions': return '추가 확인 질문';
      case 'raw':       return 'AI 응답';
      default:          return '분석 결과';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: _color, size: 16),
                const SizedBox(width: 6),
                Text(
                  _label,
                  style: TextStyle(
                    color: _color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}