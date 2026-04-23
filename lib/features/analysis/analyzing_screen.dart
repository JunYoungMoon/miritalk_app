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
import 'package:miritalk_app/core/storage/guest_token_storage.dart';
import 'package:miritalk_app/features/home/conversation_provider.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';

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
  bool _isDone = false;
  int _dotCount = 1;
  late Timer _dotTimer;

  final Map<int, String> _stepStates = {
    0: 'pending',
    1: 'pending',
    2: 'pending',
    3: 'pending',
  };

  final List<ChatMessage> _messages = [];
  StreamSubscription? _sseSubscription;
  String? _guestImageToken;

  @override
  void initState() {
    super.initState();

    _dotTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });

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

    AdManager.instance.loadInterstitial();
    _startAnalysis();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _progressController.dispose();
    _shimmerController.dispose();
    _dotTimer.cancel();
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
        // ── 추가: done 이벤트 없이 스트림이 닫힌 경우 ──
        onDone: () {
          if (!mounted || _isDone) return;
          Navigator.pop(
            context,
            const AnalysisError('SERVER_ERROR', '분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
          );
        },
      );
    } on FileTooLargeException {
      if (mounted) Navigator.pop(context, const AnalysisError('FILE_TOO_LARGE', '파일 크기가 너무 큽니다. 최대 10MB까지 업로드 가능합니다.'));
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
              categoryName: json['categoryName'] as String?,
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
        String? categoryName;
        if (sessionId != null && _guestImageToken != null) {
          try {
            // 이미지 URL + categoryName 동시에 결과 API에서 가져오기
            final response = await ApiClient().get(
              '/api/fraud/result/guest/$sessionId?token=$_guestImageToken',
            );
            final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
            guestImageUrls = (json['imageUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ?? [];
            categoryName = json['categoryName'] as String?;
          } catch (e) {
            debugPrint('게스트 결과 조회 실패: $e');
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
              categoryName: categoryName,
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

    if (sessionId != null) {
      // 분석 내역 갱신
      if (context.mounted) {
        context.read<ConversationProvider>().loadConversations(refresh: true);
      }
      _navigateToResult(sessionId);
    }
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
    addIfMissing('psychologicalTactics', json['psychologicalTactics']);
    addIfMissing('suspicious', json['suspiciousPoints']);
    addIfMissing('action',    json['recommendedActions']);
    addIfMissing('questions', json['additionalQuestions']);

    return result;
  }

  void _handleSSEData(String data) {
    try {
      final json = jsonDecode(data);
      final type = json['type'] as String;

      if (type == 'step') {
        final step = json['step'] as int? ?? 0;
        final state = json['state'] as String? ?? 'start';
        if (mounted) setState(() {
          _stepStates[step] = state == 'done' ? 'done' : 'active';
        });
        return;
      }

      if (type == 'riskScore') {
        _riskScore = int.tryParse(json['content'] as String? ?? '');
      } else if (type == 'riskLevel') {
        _riskLevel = json['content'] as String?;
      } else if (type == 'error') {
        final errorCode = json['errorCode'] as String? ?? 'UNKNOWN_ERROR';
        final message = json['message'] as String? ?? '오류가 발생했습니다.';
        if (mounted) Navigator.pop(context, AnalysisError(errorCode, message));
        return;
      } else if (type == 'done') {
        _isDone = true;
        final sessionId = json['sessionId'] as int?;
        _guestImageToken = json['imageToken'] as String?;

        // 토큰 로컬 저장
        if (sessionId != null && _guestImageToken != null) {
          GuestTokenStorage.save(sessionId, _guestImageToken!);
        }

        _onDone(sessionId);
        return;
      }

      final content = json['content'] as String? ?? '';
      if (content.isEmpty) return;
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
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          automaticallyImplyLeading: false,
          title: Text('분석중${'.' * _dotCount}',
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontSize: 17, fontWeight: FontWeight.w700)),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    children: [
                      // ── Orb ──
                      _AnalysisOrb(shimmerAnimation: _shimmerAnimation),

                      const SizedBox(height: 20),

                      // ── 타이틀 ──
                      const Text(
                        'AI가 대화를 분석하고 있어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── 서브타이틀 ──
                      const Text(
                        '보통 15~30초 정도 소요됩니다.\n잠시만 기다려 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.6,
                          letterSpacing: -0.15,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── 프로그레스바 ──
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, _) {
                          final percent =
                          (_progressAnimation.value * 100).toInt();
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Container(
                                  height: 4,
                                  color: AppTheme.surface,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: _progressAnimation.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppTheme.primary,
                                              Color(0xFFBDB0FF),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('진행률',
                                      style: TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 11)),
                                  Text(
                                    '$percent%',
                                    style: const TextStyle(
                                      color: Color(0xFFBDB0FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      _StepsCard(
                        stepStates: _stepStates,
                        shimmerAnimation: _shimmerAnimation,
                        messages: _messages,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ── Tip 박스 (하단 고정) ──
              const _TipBox(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── shimmer 링이 감싸는 아이콘 ───────────────────────
class _AnalysisOrb extends StatelessWidget {
  final Animation<double> shimmerAnimation;
  const _AnalysisOrb({required this.shimmerAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (_, __) {
        return SizedBox(
          width: 260, height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 바깥 링 2
              Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
              // 바깥 링 1
              Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              // orb 본체
              Container(
                width: 180, height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    radius: 0.9,
                    colors: [
                      Color(0xFFBDB0FF),
                      AppTheme.primaryDeep,
                      AppTheme.background,
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              // 회전 sweep 글로우
              Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(
                        shimmerAnimation.value * 2 * pi),
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // 아이콘
              const Icon(Icons.psychology_outlined,
                  color: Colors.white, size: 52),
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

class _StepsCard extends StatelessWidget {
  final Map<int, String> stepStates;
  final Animation<double> shimmerAnimation;
  final List<ChatMessage> messages;

  static const _labels = [
    '이미지 업로드',
    '사기 패턴 감지',
    '심리 조작 기법 분석',
    '결과 리포트 생성',
  ];

  const _StepsCard({
    required this.stepStates,
    required this.shimmerAnimation,
    this.messages = const [],
  });

  String get _streamText {
    if (messages.isEmpty) return '';
    final streamMsg = messages.lastWhere(
          (m) => m.type == 'stream',
      orElse: () => messages.last,
    );
    final text = streamMsg.text;
    return text.length > 120
        ? '...${text.substring(text.length - 120)}'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(_labels.length, (i) {
          final state = stepStates[i] ?? 'pending';
          final isDone   = state == 'done';
          final isActive = state == 'active';

          // 결과 리포트(step 3)가 active일 때만 스트리밍 텍스트 표시
          final showStream = isActive && i == _labels.length - 1
              && messages.isNotEmpty;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: i < _labels.length - 1
                ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.divider, width: 0.5),
              ),
            )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 상태 원
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppTheme.success.withValues(alpha: 0.13)
                            : isActive
                            ? AppTheme.primary.withValues(alpha: 0.13)
                            : AppTheme.surfaceDeep,
                        border: Border.all(
                          color: isDone
                              ? AppTheme.success
                              : isActive
                              ? AppTheme.primary
                              : AppTheme.divider,
                          width: 1,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                          color: AppTheme.success, size: 13)
                          : isActive
                          ? Center(
                        child: Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _labels[i],
                        style: TextStyle(
                          color: isDone
                              ? AppTheme.textSecondary
                              : isActive
                              ? AppTheme.textPrimary
                              : AppTheme.textHint,
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                    if (isActive)
                      _BlinkingDots(shimmerAnimation: shimmerAnimation),
                  ],
                ),

                // 스트리밍 텍스트
                if (showStream) ...[
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: shimmerAnimation,
                    builder: (_, __) => ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppTheme.textPrimary],
                        stops: [0.0, 0.35],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: Text(
                        _streamText,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          height: 1.6,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_outlined,
              color: AppTheme.warning, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.6),
                children: [
                  TextSpan(
                    text: 'Tip. ',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '분석이 끝나면 알림으로 알려드려요. 앱을 닫아도 됩니다.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}