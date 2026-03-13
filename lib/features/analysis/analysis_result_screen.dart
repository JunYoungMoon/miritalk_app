// lib/features/analysis/analysis_result_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class AnalysisResultScreen extends StatefulWidget {
  final String analysisId; // 서버에서 발급한 분석 ID

  const AnalysisResultScreen({super.key, required this.analysisId});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = true;
  StreamSubscription? _sseSubscription;

  @override
  void initState() {
    super.initState();
    _connectSSE();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _connectSSE() {
    final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/fraud/result/${widget.analysisId}');

    final client = http.Client();
    final request = http.Request('GET', uri);
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    client.send(request).then((response) {
      _sseSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
          if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            if (data == '[DONE]') {
              setState(() => _isStreaming = false);
              client.close();
              return;
            }
            _handleSSEData(data);
          }
        },
        onDone: () {
          setState(() => _isStreaming = false);
          client.close();
        },
        onError: (_) {
          setState(() => _isStreaming = false);
          client.close();
        },
      );
    });
  }

  void _handleSSEData(String data) {
    try {
      final json = jsonDecode(data);
      final type = json['type'] as String;
      final content = json['content'] as String;

      setState(() {
        // 같은 type의 마지막 메시지에 이어붙이기 (스트리밍 효과)
        if (_messages.isNotEmpty && _messages.last.type == type && _messages.last.isStreaming) {
          _messages.last = _messages.last.copyWith(
            text: _messages.last.text + content,
          );
        } else {
          _messages.add(_ChatMessage(type: type, text: content, isStreaming: true));
        }
      });

      // 완료 신호
      if (json['done'] == true && _messages.isNotEmpty) {
        setState(() => _messages.last = _messages.last.copyWith(isStreaming: false));
      }

      _scrollToBottom();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),

          // 스트리밍 중 표시
          if (_isStreaming)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '분석 중...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// _ChatMessage 모델 (같은 파일 하단에 추가)
class _ChatMessage {
  final String type; // 'summary' | 'risk' | 'suspicious' | 'action'
  final String text;
  final bool isStreaming;

  const _ChatMessage({
    required this.type,
    required this.text,
    this.isStreaming = false,
  });

  _ChatMessage copyWith({String? text, bool? isStreaming}) {
    return _ChatMessage(
      type: type,
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

// _ChatBubble 위젯 (같은 파일 하단에 추가)
class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  IconData get _icon {
    switch (message.type) {
      case 'risk': return Icons.warning_amber_rounded;
      case 'suspicious': return Icons.search_rounded;
      case 'action': return Icons.tips_and_updates_outlined;
      default: return Icons.smart_toy_outlined;
    }
  }

  Color get _color {
    switch (message.type) {
      case 'risk': return AppTheme.danger;
      case 'suspicious': return Colors.orange;
      case 'action': return AppTheme.success;
      default: return AppTheme.primary;
    }
  }

  String get _label {
    switch (message.type) {
      case 'risk': return '위험도';
      case 'suspicious': return '의심 포인트';
      case 'action': return '권장 행동';
      default: return '종합 분석';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                if (message.isStreaming) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.2,
                      color: _color,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
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