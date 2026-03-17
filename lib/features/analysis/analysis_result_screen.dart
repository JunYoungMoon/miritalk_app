// lib/features/analysis/analysis_result_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'dart:typed_data';
import 'package:miritalk_app/core/config/app_config.dart';

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
  final int? sessionId; // 히스토리에서 올 때 사용

  const AnalysisResultScreen({
    super.key,
    this.messages = const [],
    this.imageUrls = const [],
    this.sessionId,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  late List<ChatMessage> _messages;
  late List<String> _imageUrls;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages = widget.messages;
    _imageUrls = widget.imageUrls;

    // sessionId만 있고 messages가 없으면 API로 조회 (히스토리 진입)
    if (widget.sessionId != null && widget.messages.isEmpty) {
      _loadFromApi(widget.sessionId!);
    }
  }

  Future<void> _loadFromApi(int sessionId) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('/api/fraud/result/$sessionId');
      final json = jsonDecode(response.body);

      setState(() {
        _imageUrls = (json['imageUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [];
        _messages = [
          if (json['summary'] != null)
            ChatMessage(type: 'summary', text: json['summary']),
          if (json['riskScore'] != null)
            ChatMessage(type: 'riskScore', text: json['riskScore'].toString()),
          if (json['riskLevel'] != null)
            ChatMessage(type: 'riskLevel', text: json['riskLevel']),
          if (json['suspiciousPoints'] != null)
            ChatMessage(type: 'suspicious', text: json['suspiciousPoints']),
          if (json['recommendedActions'] != null)
            ChatMessage(type: 'action', text: json['recommendedActions']),
          if (json['additionalQuestions'] != null)
            ChatMessage(type: 'questions', text: json['additionalQuestions']),
        ];
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
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final riskLevel = _findText('riskLevel');
    final riskScore = _findText('riskScore');
    final riskColor = _riskColor(riskLevel);

    final displayMessages = _messages
        .where((m) =>
    m.type != 'stream' &&
        m.type != 'riskLevel' &&
        m.type != 'riskScore')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(title: '분석 결과'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
        children: [
          if (_imageUrls.isNotEmpty)
            _ThumbnailStrip(imageUrls: _imageUrls),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _RiskHeaderCard(
                  riskLevel: riskLevel,
                  riskScore: riskScore,
                  riskColor: riskColor,
                ),
                const SizedBox(height: 8),
                ...displayMessages.map((m) => _ChatBubble(message: m)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 상단 가로 썸네일 스트립 ──────────────────────────
class _ThumbnailStrip extends StatelessWidget {
  final List<String> imageUrls;
  const _ThumbnailStrip({required this.imageUrls});

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
          // 레이블
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primary, size: 13),
                const SizedBox(width: 5),
                const Text(
                  '분석한 이미지',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${imageUrls.length}장 · 탭하면 확대됩니다',
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 11),
                ),
              ],
            ),
          ),

          // 가로 스크롤 썸네일 리스트
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
                          child: _AuthImage(url: imageUrls[index], fit: BoxFit.cover),
                        ),

                        // 대표 뱃지 (첫 번째만)
                        if (isFirst)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 2),
                              child: const Text(
                                '대표',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // 번호 뱃지
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 핀치 줌 + 좌우 스와이프
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            // ← Image.network 대신 _AuthImage
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: _AuthImage(
                  url: widget.imageUrls[index],
                  fit: BoxFit.contain,
                  fullscreen: true,
                ),
              ),
            ),
          ),

          // 하단 인디케이터
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
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
                  const Text(
                    '사기 위험도',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
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
                      valueColor:
                      AlwaysStoppedAnimation<Color>(riskColor),
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
      case 'summary':    return Icons.smart_toy_outlined;
      case 'suspicious': return Icons.search_rounded;
      case 'action':     return Icons.tips_and_updates_outlined;
      case 'questions':  return Icons.help_outline_rounded;
      default:           return Icons.info_outline;
    }
  }

  Color get _color {
    switch (message.type) {
      case 'suspicious': return Colors.orange;
      case 'action':     return AppTheme.success;
      case 'questions':  return Colors.blue;
      default:           return AppTheme.primary;
    }
  }

  String get _label {
    switch (message.type) {
      case 'summary':    return '종합 분석';
      case 'suspicious': return '의심 포인트';
      case 'action':     return '권장 행동';
      case 'questions':  return '추가 확인 질문';
      default:           return '분석 결과';
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

// analysis_result_screen.dart 파일 맨 아래에 추가
class _AuthImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool fullscreen;

  const _AuthImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.fullscreen = false,
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
      final path = widget.url.replaceFirst(AppConfig.baseUrl, '');
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) return response.bodyBytes;
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
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.primary,
                ),
              ),
            ),
          );
        }
        if (snapshot.data == null) {
          return Container(
            color: widget.fullscreen ? Colors.black : AppTheme.surfaceDeep,
            child: Icon(
              Icons.broken_image_outlined,
              color: widget.fullscreen ? Colors.white38 : AppTheme.textHint,
              size: widget.fullscreen ? 60 : 24,
            ),
          );
        }
        return Image.memory(snapshot.data!, fit: widget.fit);
      },
    );
  }
}