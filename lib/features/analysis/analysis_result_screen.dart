// lib/features/analysis/analysis_result_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'dart:typed_data';
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/core/ads/banner_ad_widget.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';
import 'package:miritalk_app/core/tracking/screen_time_tracker.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String type;
  final String text;
  final bool isDone;

  const ChatMessage({
    required this.type,
    required this.text,
    this.isDone = false,
  });

  ChatMessage copyWith({String? text, bool? isDone}) => ChatMessage(
    type: type,
    text: text ?? this.text,
    isDone: isDone ?? this.isDone,
  );
}

class AnalysisResultScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  final List<String> imageUrls;
  final int? sessionId;
  final bool? feedbackHelpful;
  final String? guestImageToken;

  const AnalysisResultScreen({
    super.key,
    this.messages = const [],
    this.imageUrls = const [],
    this.sessionId,
    this.feedbackHelpful,
    this.guestImageToken,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  late List<ChatMessage> _messages;
  late List<String> _imageUrls;
  bool _isLoading = false;
  bool _feedbackSubmitted = false;
  bool? _feedbackHelpful;
  late final ScreenTimeTracker _tracker;

  @override
  void initState() {
    super.initState();
    _tracker = ScreenTimeTracker('analysis_result'); //체류시간 측정
    TrackingService.instance.logScreen('analysis_result'); //화면 진입 횟수
    _messages = widget.messages;
    _imageUrls = widget.imageUrls;
    if (widget.feedbackHelpful != null) {
      _feedbackSubmitted = true;
      _feedbackHelpful = widget.feedbackHelpful;
    }
    if (widget.sessionId != null && widget.messages.isEmpty) {
      _loadFromApi(widget.sessionId!);
    }
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _loadFromApi(int sessionId) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('/api/fraud/result/$sessionId');
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      setState(() {
        _imageUrls = (json['imageUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        _messages = [
          if (json['summary'] != null)
            ChatMessage(type: 'summary', text: json['summary'] as String, isDone: true),
          if (json['riskScore'] != null)
            ChatMessage(type: 'riskScore', text: json['riskScore'].toString(), isDone: true),
          if (json['riskLevel'] != null)
            ChatMessage(type: 'riskLevel', text: json['riskLevel'] as String, isDone: true),
          if (json['verdict'] != null)
            ChatMessage(type: 'verdict', text: json['verdict'] as String, isDone: true),
          if (json['psychologicalTactics'] != null)
            ChatMessage(type: 'psychologicalTactics', text: json['psychologicalTactics'] as String, isDone: true),
          if (json['suspiciousPoints'] != null)
            ChatMessage(type: 'suspicious', text: json['suspiciousPoints'] as String, isDone: true),
          if (json['recommendedActions'] != null)
            ChatMessage(type: 'action', text: json['recommendedActions'] as String, isDone: true),
          if (json['additionalQuestions'] != null)
            ChatMessage(type: 'questions', text: json['additionalQuestions'] as String, isDone: true),
        ];
        if (json['feedbackHelpful'] != null) {
          _feedbackSubmitted = true;
          _feedbackHelpful = json['feedbackHelpful'] as bool;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _findText(String type) {
    try {
      return _messages.firstWhere((m) => m.type == type).text;
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: const CommonAppBar(title: '분석 결과'),
        body: const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final riskLevel = _findText('riskLevel');
    final riskScore = _findText('riskScore');
    final verdict   = _findText('verdict');
    final riskColor = _riskColor(riskLevel);

    final displayMessages = _messages
        .where((m) =>
    m.type != 'stream' &&
        m.type != 'riskLevel' &&
        m.type != 'riskScore' &&
        m.type != 'verdict')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(title: '분석 결과'),
      // bottomNavigationBar: const BannerAdWidget(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
        children: [
          if (_imageUrls.isNotEmpty)
            _ThumbnailStrip(
              imageUrls: _imageUrls,
              isGuest: widget.guestImageToken != null,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _RiskHeaderCard(
                  riskLevel: riskLevel,
                  riskScore: riskScore,
                  verdict: verdict,
                  riskColor: riskColor,
                ),
                const SizedBox(height: 8),
                ...displayMessages.map((m) => _buildCard(m)),
                const SizedBox(height: 8),
                if (widget.guestImageToken == null)
                  _FeedbackCard(
                    sessionId: widget.sessionId,
                    submitted: _feedbackSubmitted,
                    helpful: _feedbackHelpful,
                    onFeedback: _submitFeedback,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 타입별 카드 라우팅
  Widget _buildCard(ChatMessage m) {
    switch (m.type) {
      case 'summary':
        return _SummaryCard(text: m.text);
      case 'psychologicalTactics':
        return _PsychologicalTacticsCard(json: m.text);
      case 'suspicious':
        return _SuspiciousCard(json: m.text);
      case 'action':
        return _ActionCard(json: m.text);
      case 'questions':
        return _QuestionsCard(json: m.text);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submitFeedback(bool helpful, String? reason) async {
    TrackingService.instance.logFeedbackSubmitted(helpful: helpful, reason: reason);
    final sessionId = widget.sessionId;
    if (sessionId == null) return;
    try {
      await ApiClient().post('/api/fraud/feedback', body: {
        'sessionId': sessionId,
        'helpful': helpful,
        if (reason != null) 'reason': reason,
      });
    } catch (_) {}
    setState(() {
      _feedbackSubmitted = true;
      _feedbackHelpful = helpful;
    });
  }

}

// ── 공통 섹션 컨테이너 ───────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── 종합 분석 ────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String text;
  const _SummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.smart_toy_outlined,
      label: '종합 분석',
      color: AppTheme.primary,
      child: Text(text,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 14, height: 1.6)),
    );
  }
}

// ── 심리 조작 기법 (아코디언) ────────────────────────
class _PsychologicalTacticsCard extends StatelessWidget {
  final String json;
  const _PsychologicalTacticsCard({required this.json});

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try { items = jsonDecode(json) as List; } catch (_) {}
    if (items.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.psychology_outlined,
      label: '심리 조작 기법',
      color: Colors.purple,
      child: Column(
        children: items.map((item) {
          final tactic  = item['tactic']  as String? ?? '';
          final evidence = item['evidence'] as String? ?? '';
          return _AccordionItem(
            title: tactic,
            content: evidence,
            color: Colors.purple,
          );
        }).toList(),
      ),
    );
  }
}

// ── 아코디언 아이템 ──────────────────────────────────
class _AccordionItem extends StatefulWidget {
  final String title;
  final String content;
  final Color color;
  const _AccordionItem({
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  State<_AccordionItem> createState() => _AccordionItemState();
}

class _AccordionItemState extends State<_AccordionItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: TextStyle(
                            color: widget.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: widget.color,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  widget.content,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 의심 포인트 ──────────────────────────────────────
class _SuspiciousCard extends StatelessWidget {
  final String json;
  const _SuspiciousCard({required this.json});

  static const _categoryColor = {
    '행동': Colors.orange,
    '인증': Colors.red,
    '계좌': Colors.deepOrange,
    '사진': Colors.purple,
    '신원': Colors.pink,
  };

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try { items = jsonDecode(json) as List; } catch (_) {}
    if (items.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.search_rounded,
      label: '의심 포인트',
      color: Colors.orange,
      child: Column(
        children: items.map((item) {
          final category    = item['category']    as String? ?? '';
          final description = item['description'] as String? ?? '';
          final color = _categoryColor[category] ?? Colors.orange;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(category,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(description,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 권장 행동 (타임라인) ─────────────────────────────
class _ActionCard extends StatelessWidget {
  final String json;
  const _ActionCard({required this.json});

  static const _priorityStyle = {
    '즉시':  {'color': Colors.red,    'icon': Icons.warning_rounded},
    '단기':  {'color': Colors.orange, 'icon': Icons.schedule_rounded},
    '참고':  {'color': Colors.blue,   'icon': Icons.info_outline},
  };

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try { items = jsonDecode(json) as List; } catch (_) {}
    if (items.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.tips_and_updates_outlined,
      label: '권장 행동',
      color: AppTheme.success,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index    = entry.key;
          final item     = entry.value;
          final priority = item['priority'] as String? ?? '';
          final action   = item['action']   as String? ?? '';
          final style    = _priorityStyle[priority] ?? _priorityStyle['참고']!;
          final color    = style['color'] as Color;
          final icon     = style['icon']  as IconData;
          final isLast   = index == items.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타임라인 라인 + 아이콘
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 14),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: color.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // 내용
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(priority,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 5),
                        Text(action,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 추가 확인 질문 ───────────────────────────────────
class _QuestionsCard extends StatelessWidget {
  final String json;
  const _QuestionsCard({required this.json});

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try { items = jsonDecode(json) as List; } catch (_) {}
    if (items.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.help_outline_rounded,
      label: '추가 확인 질문',
      color: Colors.blue,
      child: Column(
        children: items.map((item) {
          final purpose  = item['purpose']  as String? ?? '';
          final question = item['question'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // purpose 힌트
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.blue, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(purpose,
                          style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              height: 1.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 말풍선 스타일 질문
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Text(question,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 위험도 헤더 카드 (verdict 포함) ─────────────────
class _RiskHeaderCard extends StatelessWidget {
  final String riskLevel;
  final String riskScore;
  final String verdict;
  final Color riskColor;

  const _RiskHeaderCard({
    required this.riskLevel,
    required this.riskScore,
    required this.verdict,
    required this.riskColor,
  });

  static const _verdictStyle = {
    '거래진행가능':   {'color': AppTheme.success, 'icon': Icons.check_circle_outline},
    '추가검증필요':   {'color': Colors.orange,    'icon': Icons.help_outline},
    '거래중단권고':   {'color': Colors.deepOrange,'icon': Icons.warning_amber_rounded},
    '즉시중단':      {'color': AppTheme.danger,   'icon': Icons.cancel_outlined},
  };

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(riskScore) ?? 0;
    final vs    = _verdictStyle[verdict];
    final verdictColor = vs?['color'] as Color? ?? AppTheme.textHint;
    final verdictIcon  = vs?['icon']  as IconData? ?? Icons.info_outline;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withValues(alpha: 0.2), AppTheme.surface],
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
                  const Text('사기 위험도',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    riskLevel.isEmpty ? '분석 중' : riskLevel,
                    style: TextStyle(
                        color: riskColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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
                  Text('$score%',
                      style: TextStyle(
                          color: riskColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceDeep,
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
            ),
          ),
          // verdict 뱃지
          if (verdict.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: verdictColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: verdictColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(verdictIcon, color: verdictColor, size: 16),
                  const SizedBox(width: 6),
                  Text(verdict,
                      style: TextStyle(
                          color: verdictColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 상단 가로 썸네일 스트립 ──────────────────────────
class _ThumbnailStrip extends StatelessWidget {
  final List<String> imageUrls;
  final bool isGuest;

  const _ThumbnailStrip({
    required this.imageUrls,
    this.isGuest = false,
  });

  void _openFullscreen(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primary, size: 13),
                const SizedBox(width: 5),
                const Text('분석한 이미지',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('${imageUrls.length}장 · 탭하면 확대됩니다',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final isFirst = index == 0;
                return GestureDetector(
                  onTap: () => _openFullscreen(context, index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 72,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _AuthImage(
                            url: imageUrls[index],
                            fit: BoxFit.cover,
                            isGuest: isGuest,
                          ),
                        ),
                        if (isFirst)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.overlayDark,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 2),
                              child: const Text('대표',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        Positioned(
                          top: 3, right: 3,
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.overlayLight,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('${index + 1}',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 풀스크린 이미지 뷰어 ────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool isGuest;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
    this.isGuest = false,
  });

  @override
  State<_FullscreenImageViewer> createState() =>
      _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: _AuthImage(
                  url: widget.imageUrls[index],
                  fit: BoxFit.contain,
                  fullscreen: true,
                  isGuest: widget.isGuest,
                ),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.imageUrls.asMap().entries.map((entry) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _currentIndex == entry.key ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: _currentIndex == entry.key
                          ? AppTheme.primary
                          : Colors.white30,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 인증 이미지 로더 ────────────────────────────────
class _AuthImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool fullscreen;
  final bool isGuest;

  const _AuthImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.fullscreen = false,
    this.isGuest = false,
  });

  @override
  State<_AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<_AuthImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List?> _load() async {
    try {
      if (widget.isGuest) {
        // 게스트: 토큰이 URL에 포함되어 있으므로 인증 없이 요청
        final response = await http.get(Uri.parse(widget.url));
        if (response.statusCode == 200) return response.bodyBytes;
      } else {
        // 로그인 유저: JWT 인증 필요
        final path = widget.url.replaceFirst(AppConfig.baseUrl, '');
        final response = await ApiClient().get(path);
        if (response.statusCode == 200) return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: widget.fullscreen ? Colors.black : AppTheme.surfaceDeep,
            child: Center(
              child: SizedBox(
                width: widget.fullscreen ? 32 : 16,
                height: widget.fullscreen ? 32 : 16,
                child: const CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppTheme.primary),
              ),
            ),
          );
        }
        if (snapshot.data == null) {
          return Container(
            color: widget.fullscreen ? Colors.black : AppTheme.surfaceDeep,
            child: Icon(Icons.broken_image_outlined,
                color:
                widget.fullscreen ? Colors.white38 : AppTheme.textHint,
                size: widget.fullscreen ? 60 : 24),
          );
        }
        return Image.memory(snapshot.data!, fit: widget.fit);
      },
    );
  }
}

// ── 피드백 카드 ─────────────────────────────────────
class _FeedbackCard extends StatefulWidget {
  final int? sessionId;
  final bool submitted;
  final bool? helpful;
  final Future<void> Function(bool helpful, String? reason) onFeedback;

  const _FeedbackCard({
    required this.sessionId,
    required this.submitted,
    required this.helpful,
    required this.onFeedback,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _showReasons = false;
  bool _isLoading = false;

  static const _reasons = [
    '분석이 틀린 것 같아요',
    '설명이 부족해요',
    '사기 여부를 판단하기 어려워요',
    '기타',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.sessionId == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: widget.submitted ? _buildDone() : _buildForm(),
    );
  }

  Widget _buildDone() => Row(
    children: [
      Icon(
        widget.helpful == true
            ? Icons.thumb_up_rounded
            : Icons.thumb_down_rounded,
        color:
        widget.helpful == true ? AppTheme.success : Colors.orange,
        size: 18,
      ),
      const SizedBox(width: 8),
      Text(
        widget.helpful == true
            ? '도움됐다고 평가하셨습니다'
            : '아쉽다고 평가하셨습니다',
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 13),
      ),
    ],
  );

  Widget _buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('이 분석이 도움이 됐나요?',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (!_showReasons)
        Row(children: [
          Expanded(
            child: _FeedbackButton(
              icon: Icons.thumb_up_rounded,
              label: '도움됐어요',
              color: AppTheme.success,
              isLoading: _isLoading,
              onTap: () async {
                setState(() => _isLoading = true);
                await widget.onFeedback(true, null);
                setState(() => _isLoading = false);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FeedbackButton(
              icon: Icons.thumb_down_rounded,
              label: '아쉬워요',
              color: Colors.orange,
              isLoading: _isLoading,
              onTap: () => setState(() => _showReasons = true),
            ),
          ),
        ]),
      if (_showReasons) ...[
        const Text('어떤 점이 아쉬웠나요?',
            style:
            TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _reasons.map((reason) {
            return GestureDetector(
              onTap: () async {
                setState(() => _isLoading = true);
                await widget.onFeedback(false, reason);
                setState(() => _isLoading = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Text(reason,
                    style: const TextStyle(
                        color: Colors.orange, fontSize: 12)),
              ),
            );
          }).toList(),
        ),
      ],
    ],
  );
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GuestFullscreenViewer extends StatefulWidget {
  final List<Uint8List> imageBytes;
  final int initialIndex;
  const _GuestFullscreenViewer(
      {required this.imageBytes, required this.initialIndex});

  @override
  State<_GuestFullscreenViewer> createState() => _GuestFullscreenViewerState();
}

class _GuestFullscreenViewerState extends State<_GuestFullscreenViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${_currentIndex + 1} / ${widget.imageBytes.length}',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageBytes.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(widget.imageBytes[index], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}