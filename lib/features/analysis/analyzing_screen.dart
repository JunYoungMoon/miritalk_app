// lib/features/analysis/analyzing_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'analysis_result_screen.dart';
import 'package:miritalk_app/core/network/api_client.dart';

class AnalyzingScreen extends StatefulWidget {
  final List<http.MultipartFile> images;
  const AnalyzingScreen({super.key, required this.images});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  final List<String> _steps = [
    '이미지에서 텍스트를 추출하고 있습니다...',
    '대화 패턴을 분석하고 있습니다...',
    '사기 사례와 비교하고 있습니다...',
    '분석 결과를 정리하고 있습니다...',
  ];
  int _currentStep = 0;
  final List<ChatMessage> _messages = [];
  StreamSubscription? _sseSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();

    _progressAnimation = Tween<double>(begin: 0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return false;
      setState(() => _currentStep = (_currentStep + 1) % _steps.length);
      return true;
    });

    _startAnalysis();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    try {
      final streamed = await ApiClient().postMultipartStream(
        '/api/fraud/analyze',
        files: widget.images,
      );

      _sseSubscription = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
          if (!line.startsWith('data:')) return;
          final data = line.substring(5).trim();

          if (data == '[DONE]') {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AnalysisResultScreen(
                    messages: _messages,
                    imageUrls: const [],
                  ),
                ),
              );
            }
            return;
          }
          _handleSSEData(data);
        },
        onError: (_) { if (mounted) Navigator.pop(context); },
      );
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('분석 오류: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _handleSSEData(String data) {
    try {
      final json = jsonDecode(data);
      final type = json['type'] as String;
      final content = json['content'] as String;
      final done = json['done'] as bool? ?? false;

      setState(() {
        if (_messages.isNotEmpty &&
            _messages.last.type == type &&
            !_messages.last.isDone) {
          _messages.last = _messages.last.copyWith(
            text: _messages.last.text + content,
            isDone: done,
          );
        } else {
          _messages.add(ChatMessage(type: type, text: content, isDone: done));
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.manage_search_rounded,
                    color: AppTheme.primary, size: 40),
              ),
              const SizedBox(height: 32),
              const Text(
                '대화 내역을 면밀하게\n분석 중입니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _steps[_currentStep],
                  key: ValueKey(_currentStep),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, _) => Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: AppTheme.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progressAnimation.value * 100).toInt()}%',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}