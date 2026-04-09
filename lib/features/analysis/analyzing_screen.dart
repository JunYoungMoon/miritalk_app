// lib/features/analysis/analyzing_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'analysis_result_screen.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/features/analysis/analysis_error.dart';
import 'package:miritalk_app/core/ads/ad_manager.dart';
import 'package:miritalk_app/core/ads/banner_ad_widget.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';
import 'dart:typed_data';

class AnalyzingScreen extends StatefulWidget {
  final List<http.MultipartFile> images;
  final bool isGuest;
  final List<Uint8List>? guestImageBytes;
  final String? guestFcmToken;

  const AnalyzingScreen({
    super.key,
    required this.images,
    required this.isGuest,
    this.guestImageBytes,
    this.guestFcmToken,
  });

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with TickerProviderStateMixin {
  // 프로그레스 애니메이션 — 60초로 연장
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // shimmer 애니메이션
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  int? _riskScore;
  String? _riskLevel;

  final List<String> _steps = [
    '이미지에서 텍스트를 추출하고 있습니다...',
    '대화 패턴을 분석하고 있습니다...',
    '사기 사례와 비교하고 있습니다...',
    '심리 조작 기법을 탐지하고 있습니다...',
    '분석 결과를 정리하고 있습니다...',
  ];
  int _currentStep = 0;
  final List<ChatMessage> _messages = [];
  StreamSubscription? _sseSubscription;
  String? _guestImageToken;

  @override
  void initState() {
    super.initState();

    // ── 프로그레스바: 60초 동안 0 → 0.95
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..forward();

    _progressAnimation = Tween<double>(begin: 0, end: 0.95).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // ── shimmer: 1.8초 루프
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // 스텝 텍스트 순환
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      setState(() => _currentStep = (_currentStep + 1) % _steps.length);
      return true;
    });

    AdManager.instance.loadInterstitial();
    _startAnalysis();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _progressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    await TrackingService.instance.logAnalysisRequested(
      imageCount: widget.images.length,
      isGuest: widget.isGuest,
    );

    try {
      final endpoint = widget.isGuest
          ? '/api/fraud/analyze/guest'
          : '/api/fraud/analyze';

      final streamed = await ApiClient().postMultipartStream(
        endpoint,
        files: widget.images,
        includeDeviceId: widget.isGuest, // 게스트만 X-Device-Id 헤더 추가
        fcmToken: widget.guestFcmToken,
      );

      _sseSubscription = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
          if (!line.startsWith('data:')) return;
          final data = line.substring(5).trim();
          _handleSSEData(data);
        },
        onError: (_) {
          if (mounted) {
            Navigator.pop(
              context,
              const AnalysisError('NETWORK_ERROR', '네트워크 연결이 끊겼습니다. 다시 시도해주세요.'),
            );
          }
        },
      );
    } on QuotaExceededException catch (e) {
      if (mounted) Navigator.pop(context, AnalysisError('QUOTA_ERROR', e.message));
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context, const AnalysisError('AUTH_ERROR', ''));
    } catch (e) {
      debugPrint('분석 오류: $e');
      if (mounted) {
        Navigator.pop(
          context,
          const AnalysisError('NETWORK_ERROR', '네트워크 연결을 확인해주세요.'),
        );
      }
    }
  }

  Future<void> _navigateToResult(int sessionId) async {
    try {
      final response = await ApiClient().get('/api/fraud/result/$sessionId');
      final json = jsonDecode(response.body);

      final imageUrls = (json['imageUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];

      final mergedMessages = _buildMessages(json);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(
              messages: mergedMessages,
              imageUrls: imageUrls,
              sessionId: sessionId,
            ),
          ),
          // modalRoute.isFirst가 true가 될 때까지 이전의 모든 화면을 제거합니다.
              (Route<dynamic> route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint('결과 조회 오류: $e');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(
              messages: _messages,
              imageUrls: const [],
              sessionId: sessionId,
            ),
          ),
          // modalRoute.isFirst가 true가 될 때까지 이전의 모든 화면을 제거합니다.
              (Route<dynamic> route) => route.isFirst,
        );
      }
    }
  }

  Future<void> _onDone(int? sessionId) async {
    _progressController.stop();
    _progressController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    await TrackingService.instance.logAnalysisCompleted(
      riskScore: _riskScore ?? 0,
      riskLevel: _riskLevel ?? 'UNKNOWN',
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (widget.isGuest) {
      if (mounted) {
        // 서버에서 이미지 목록 조회 후 토큰 붙여서 URL 구성
        List<String> guestImageUrls = [];
        if (sessionId != null && _guestImageToken != null) {
          try {
            final response = await ApiClient().get(
              '/api/fraud/guest/images/$sessionId?token=$_guestImageToken',
            );
            final json = jsonDecode(response.body);
            guestImageUrls = (json['imageUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ?? [];
          } catch (e) {
            debugPrint('게스트 이미지 목록 조회 실패: $e');
          }
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(
              messages: _messages,
              imageUrls: guestImageUrls,
              sessionId: null,
              guestImageToken: _guestImageToken,
            ),
          ),
              (route) => route.isFirst,
        );
      }
      return;
    }

    // 전면광고 로직
    // AdManager.instance.showInterstitial(
    //   onClosed: () => _navigateToResult(sessionId),
    // );


    if (sessionId != null) _navigateToResult(sessionId);
  }

  List<ChatMessage> _buildMessages(Map<String, dynamic> json) {
    final existingTypes = _messages.map((m) => m.type).toSet();
    final result = List<ChatMessage>.from(_messages);

    void addIfMissing(String type, String? value) {
      if (value != null && value.isNotEmpty && !existingTypes.contains(type)) {
        result.add(ChatMessage(type: type, text: value));
      }
    }

    addIfMissing('summary',   json['summary']);
    addIfMissing('riskScore', json['riskScore']?.toString());
    addIfMissing('riskLevel', json['riskLevel']);
    addIfMissing('suspicious', json['suspiciousPoints']);
    addIfMissing('action',    json['recommendedActions']);
    addIfMissing('questions', json['additionalQuestions']);

    return result;
  }

  void _handleSSEData(String data) {
    try {
      final json = jsonDecode(data);
      final type = json['type'] as String;

      if (type == 'riskScore') {
        _riskScore = int.tryParse(json['content'] as String? ?? '');
        return;
      }
      if (type == 'riskLevel') {
        _riskLevel = json['content'] as String?;
        return;
      }

      if (type == 'error') {
        final errorCode = json['errorCode'] as String? ?? 'UNKNOWN_ERROR';
        final message = json['message'] as String? ?? '오류가 발생했습니다.';
        if (mounted) Navigator.pop(context, AnalysisError(errorCode, message));
        return;
      }

      if (type == 'done') {
        final sessionId = json['sessionId'] as int?;
        // 게스트 이미지 토큰 파싱
        _guestImageToken = json['imageToken'] as String?;
        _onDone(sessionId);
        return;
      }

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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        // bottomNavigationBar: const BannerAdWidget(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── 아이콘 (shimmer 링 효과)
                _ShimmerRing(shimmerAnimation: _shimmerAnimation),

                const SizedBox(height: 32),

                // ── 타이틀
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

                // ── 스텝 텍스트 (shimmer 효과)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _ShimmerText(
                    key: ValueKey(_currentStep),
                    text: _steps[_currentStep],
                    shimmerAnimation: _shimmerAnimation,
                  ),
                ),

                const SizedBox(height: 32),

                // ── SSE로 들어오는 실시간 텍스트 (shimmer)
                if (_messages.isNotEmpty)
                  _StreamingTextArea(
                    messages: _messages,
                    shimmerAnimation: _shimmerAnimation,
                  ),

                const SizedBox(height: 32),

                // ── 프로그레스바
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) {
                    final percent =
                    (_progressAnimation.value * 100).toInt();
                    return Column(
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
                          '$percent%',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── shimmer 링이 감싸는 아이콘 ───────────────────────
class _ShimmerRing extends StatelessWidget {
  final Animation<double> shimmerAnimation;
  const _ShimmerRing({required this.shimmerAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (_, __) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              startAngle: 0,
              endAngle: 2 * pi,
              transform: GradientRotation(shimmerAnimation.value * pi),
              colors: [
                AppTheme.primary.withValues(alpha: 0.0),
                AppTheme.primary.withValues(alpha: 0.6),
                AppTheme.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.manage_search_rounded,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── shimmer 텍스트 ───────────────────────────────────
class _ShimmerText extends StatelessWidget {
  final String text;
  final Animation<double> shimmerAnimation;

  const _ShimmerText({
    super.key,
    required this.text,
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (shimmerAnimation.value - 0.4).clamp(0.0, 1.0),
              shimmerAnimation.value.clamp(0.0, 1.0),
              (shimmerAnimation.value + 0.4).clamp(0.0, 1.0),
            ],
            colors: const [
              AppTheme.textSecondary,
              Colors.white,
              AppTheme.textSecondary,
            ],
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }
}

// ── SSE 실시간 텍스트 영역 ───────────────────────────
class _StreamingTextArea extends StatelessWidget {
  final List<ChatMessage> messages;
  final Animation<double> shimmerAnimation;

  const _StreamingTextArea({
    required this.messages,
    required this.shimmerAnimation,
  });

  String get _latestText {
    if (messages.isEmpty) return '';
    final last = messages.last;
    // 마지막 메시지에서 최대 80자만 표시
    final text = last.text;
    return text.length > 80 ? '...${text.substring(text.length - 80)}' : text;
  }

  String get _typeLabel {
    switch (messages.last.type) {
      case 'summary':             return '종합 분석 작성 중';
      case 'suspicious':          return '의심 포인트 탐지 중';
      case 'action':              return '권장 행동 도출 중';
      case 'questions':           return '확인 질문 생성 중';
      case 'psychologicalTactics':return '심리 조작 기법 분석 중';
      default:                    return '분석 중';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (_, __) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타입 레이블 + 깜빡이는 커서 점
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      stops: [
                        (shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                        shimmerAnimation.value.clamp(0.0, 1.0),
                        (shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                      ],
                      colors: const [
                        AppTheme.primary,
                        Colors.white,
                        AppTheme.primary,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      _typeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _BlinkingDots(shimmerAnimation: shimmerAnimation),
                ],
              ),
              const SizedBox(height: 8),
              // 실시간 텍스트
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.4],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Text(
                  _latestText,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 깜빡이는 점 3개 ──────────────────────────────────
class _BlinkingDots extends StatelessWidget {
  final Animation<double> shimmerAnimation;
  const _BlinkingDots({required this.shimmerAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (_, __) {
        return Row(
          children: List.generate(3, (i) {
            // 각 점마다 위상 다르게
            final phase = (shimmerAnimation.value + i * 0.3) % 1.0;
            final opacity = (sin(phase * pi)).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 3),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}