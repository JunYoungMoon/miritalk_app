// lib/features/home/home_body.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'package:miritalk_app/features/home/analysis_quota_provider.dart';
import 'package:miritalk_app/features/home/widgets/scroll_hint_arrow.dart';
import 'package:miritalk_app/core/utils/screen_secure_util.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';
import 'package:miritalk_app/core/tracking/screen_time_tracker.dart';
import 'package:miritalk_app/features/community/community_screen.dart';
import 'dart:convert';
import 'package:miritalk_app/core/network/api_client.dart';

class HomeBody extends StatefulWidget {
  final Future<void> Function() onGoToUpload;
  const HomeBody({super.key, required this.onGoToUpload});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  late AuthProvider _authProvider;
  bool _listenerAttached = false;
  late final ScreenTimeTracker _tracker;
  bool _wasLoggedIn = false;

  // 랭킹 API 데이터
  List<Map<String, dynamic>> _rankingPosts = [];
  bool _rankingLoading = true;

  // 폴백용 하드코딩 데이터 (API 실패 시 사용)
  final List<Map<String, dynamic>> _fallbackTickerItems = [
    {'riskPct': 92, 'isHigh': true,  'text': '입금 먼저 해주시면 바로 보내드려요', 'likes': 128},
    {'riskPct': 88, 'isHigh': true,  'text': '검찰청입니다. 계좌가 범죄에 연루됐습니다', 'likes': 94},
    {'riskPct': 67, 'isHigh': false, 'text': '하루 수익률 3% 보장 해드립니다', 'likes': 76},
    {'riskPct': 95, 'isHigh': true,  'text': '지금 바로 송금하지 않으면 고소합니다', 'likes': 61},
    {'riskPct': 71, 'isHigh': false, 'text': '해외 직구 대리구매 선불로 부탁드려요', 'likes': 53},
  ];

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _analyzeButtonKey = GlobalKey();
  bool _showScrollHint = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerAttached) {
      _authProvider = context.read<AuthProvider>();
      _wasLoggedIn = _authProvider.isLoggedIn;
      _authProvider.addListener(_onAuthChanged);
      _listenerAttached = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _tracker = ScreenTimeTracker('home');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkButtonVisibility();
      _refreshQuotaIfLoggedIn();
    });
    _scrollController.addListener(_checkButtonVisibility);
    _loadRanking();
  }

  @override
  void dispose() {
    _tracker.dispose();
    if (_listenerAttached) {
      _authProvider.removeListener(_onAuthChanged);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRanking() async {
    try {
      final response = await ApiClient().get('/api/community/ranking');
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (mounted) {
        setState(() {
          _rankingPosts = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _rankingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rankingLoading = false);
    }
  }

  void _refreshQuotaIfLoggedIn() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    context.read<AnalysisQuotaProvider>().loadQuota(isLoggedIn: auth.isLoggedIn);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = auth.isLoggedIn;
      _refreshQuotaIfLoggedIn();
    }
  }

  void _checkButtonVisibility() {
    final ctx = _analyzeButtonKey.currentContext;
    if (ctx == null) return;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final isVisible = buttonOffset.dy < screenHeight - renderBox.size.height;
    if (mounted && _showScrollHint != !isVisible) {
      setState(() => _showScrollHint = !isVisible);
    }
  }

  final List<Map<String, String>> _evidenceImages = [
    {'path': 'assets/images/evidence_4.jpg', 'label': '사기접수 및 검거'},
    {'path': 'assets/images/evidence_3.jpg', 'label': '사기 피해 대화'},
    {'path': 'assets/images/evidence_1.jpg', 'label': '진정서 작성'},
    {'path': 'assets/images/evidence_2.jpg', 'label': '경찰 조사'},
  ];

  Future<void> _onAnalysisTap(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final quota = context.read<AnalysisQuotaProvider>();

    if (!auth.isLoggedIn) {
      await quota.loadQuota(isLoggedIn: false);
      if (!context.mounted) return;
      if (quota.isExhausted) {
        TrackingService.instance.logQuotaExhausted(isGuest: true);
        _showGuestQuotaDialog(context);
        return;
      }
      await widget.onGoToUpload();
      if (!context.mounted) return;
      return;
    }

    await quota.loadQuota(isLoggedIn: true);
    if (!context.mounted) return;
    if (quota.isExhausted) {
      TrackingService.instance.logQuotaExhausted(isGuest: false);
      _showQuotaDialog(context, quota.usedCount, quota.maxCount);
      return;
    }

    await widget.onGoToUpload();
    if (!context.mounted) return;
  }

  void _showGuestQuotaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('분석 횟수 소진',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: const Text(
          '비로그인 1회를 사용했습니다.\n로그인하면 매일 3회 분석할 수 있어요!',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('로그인하기',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showQuotaDialog(BuildContext context, int used, int max) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: AppTheme.danger, size: 20),
            SizedBox(width: 8),
            Text('오늘 분석 횟수 초과',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          '오늘 분석 횟수($max회)를 모두 사용했습니다.\n내일 자정에 횟수가 초기화됩니다.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final quota = context.watch<AnalysisQuotaProvider>();

    // 랭킹 데이터가 있으면 API 데이터 사용, 없으면 폴백
    final tickerItems = (!_rankingLoading && _rankingPosts.isNotEmpty)
        ? _rankingPosts
        : _fallbackTickerItems;
    final useApiData = !_rankingLoading && _rankingPosts.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  12, 16, 12,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. 헤더 스토리 카드 ──
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _TagBadge(
                                        label: '실제 피해 경험 기반',
                                        color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    _TagBadge(
                                        label: '완전 무료',
                                        color: AppTheme.success),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  '사기를 당하다 보니\n전문가가 됐습니다.',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '직접 겪은 수십 건의 사기 경험을 AI에 담았어요.\n대화 캡처 한 장으로 사기 여부를 판단해드립니다.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── 사진 영역 ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                            child: SizedBox(
                              height: 130,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _EvidencePhoto(
                                      imagePath: _evidenceImages[0]['path']!,
                                      label: _evidenceImages[0]['label']!,
                                      allImages: _evidenceImages,
                                      initialIndex: 0,
                                      showZoom: true,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: _EvidencePhoto(
                                            imagePath: _evidenceImages[1]['path']!,
                                            label: _evidenceImages[1]['label']!,
                                            allImages: _evidenceImages,
                                            initialIndex: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Expanded(
                                          child: _EvidencePhoto(
                                            imagePath: _evidenceImages[2]['path']!,
                                            label: _evidenceImages[2]['label']!,
                                            allImages: _evidenceImages,
                                            initialIndex: 2,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Expanded(
                                          child: _EvidencePhoto(
                                            imagePath: _evidenceImages[3]['path']!,
                                            label: _evidenceImages[3]['label']!,
                                            allImages: _evidenceImages,
                                            initialIndex: 3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── 구분선 ──
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: AppTheme.divider,
                            indent: 18,
                            endIndent: 18,
                          ),

                          // ── 인기 분석 티커 ──
                          _FeedTicker(
                            items: tickerItems,
                            useApiData: useApiData,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityScreen(
                                    preloadedRanking: _rankingPosts.isNotEmpty
                                        ? _rankingPosts
                                        .map((e) => CommunityPost.fromJson(e))
                                        .toList()
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 2. 사기 유형 카드 ──
                    const _FraudTypeCards(),

                    const SizedBox(height: 20),

                    // ── 3. 사용 방법 안내 ──
                    const Text('이렇게 사용하세요',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    const _StepCard(
                      step: '1',
                      icon: Icons.chat_bubble_outline,
                      title: '대화 화면 캡처',
                      description: '의심되는 상대방과의 대화 내용을 캡처해 주세요.',
                      imagePath: 'assets/images/step_capture.jpg',
                    ),
                    const SizedBox(height: 10),
                    const _StepCard(
                      step: '2',
                      icon: Icons.upload_outlined,
                      title: '사진 업로드',
                      description: '캡처한 사진을 최대 5장까지 업로드합니다.',
                      imagePath: 'assets/images/step_upload.gif',
                    ),
                    const SizedBox(height: 10),
                    const _StepCard(
                      step: '3',
                      icon: Icons.analytics_outlined,
                      title: 'AI 분석',
                      description: '미리톡 AI가 사기 패턴을 분석하고 결과를 알려드립니다.',
                      imagePath: 'assets/images/step_result.gif',
                    ),

                    const SizedBox(height: 20),

                    // ── 4. 잔여 횟수 뱃지 ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _QuotaBadge(
                        used: quota.usedCount,
                        max: quota.maxCount,
                        isGuest: quota.isGuest,
                      ),
                    ),

                    // ── 5. 분석 시작 버튼 ──
                    SizedBox(
                      key: _analyzeButtonKey,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _onAnalysisTap(context),
                        icon: Icon(
                          (!auth.isLoggedIn && quota.isExhausted)
                              ? Icons.lock_outline
                              : Icons.shield_outlined,
                          color: Colors.white,
                        ),
                        label: Text(
                          (!auth.isLoggedIn && quota.isExhausted)
                              ? '로그인하고 계속 분석하기'
                              : '지금 바로 사기 분석하기',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (!auth.isLoggedIn && quota.isExhausted)
                              ? AppTheme.primary.withValues(alpha: 0.6)
                              : AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 스크롤 힌트 화살표 ──
              if (_showScrollHint)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ScrollHintArrow(
                      onTap: () => _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 사기 유형 카드 ────────────────────────────────────
class _FraudTypeCards extends StatelessWidget {
  const _FraudTypeCards();

  static const _types = [
    (icon: Icons.storefront_outlined, color: Color(0xFF4FC3F7), title: '중고거래 사기', desc: '입금 후\n잠적·미배송'),
    (icon: Icons.trending_up,         color: Color(0xFF81C784), title: '투자 사기',    desc: '고수익 미끼로\n투자 유도'),
    (icon: Icons.sports_esports_outlined, color: Color(0xFFEF9A9A), title: '게임 사기', desc: '아이템 거래 후\n잠적·미지급'),
    (icon: Icons.phone_outlined,      color: Color(0xFFCE93D8), title: '보이스피싱',   desc: '기관 사칭으로\n송금 유도'),
    (icon: Icons.work_outline,        color: Color(0xFFFFB74D), title: '취업 사기',    desc: '허위 채용으로\n개인정보 탈취'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('이런 사기를 사전에 탐지합니다',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final t = _types[index];
              return Container(
                constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon, color: t.color, size: 22),
                    const SizedBox(height: 5),
                    Text(t.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: t.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(t.desc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 9, height: 1.4)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 잔여 횟수 뱃지 ────────────────────────────────────
class _QuotaBadge extends StatelessWidget {
  final int used;
  final int max;
  final bool isGuest;
  const _QuotaBadge({required this.used, required this.max, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    final remaining = max - used;
    final isExhausted = remaining <= 0;
    final color = isExhausted ? AppTheme.danger : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(isExhausted ? Icons.block : Icons.analytics_outlined,
                color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              isExhausted
                  ? (isGuest ? '로그인하면 매일 3회 분석할 수 있어요' : '오늘 분석 횟수를 모두 사용했습니다')
                  : '오늘 남은 분석 횟수',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ]),
          if (!isExhausted)
            Text('$remaining / $max',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── 단계 안내 카드 ─────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String description;
  final String? imagePath;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(step,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, color: AppTheme.textHint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(description,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
          if (imagePath != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => _AssetFullscreenViewer(
                    images: [{'path': imagePath!, 'label': title}],
                    initialIndex: 0,
                    showWatermark: false,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(imagePath!,
                        width: 64, height: 64, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.image_outlined,
                              color: AppTheme.primary, size: 24),
                        )),
                  ),
                  Positioned(
                    top: 3, right: 3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in,
                          color: Colors.white70, size: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 풀스크린 뷰어 ────────────────────────────────────
class _AssetFullscreenViewer extends StatefulWidget {
  final List<Map<String, String>> images;
  final int initialIndex;
  final bool showWatermark;

  const _AssetFullscreenViewer({
    required this.images,
    required this.initialIndex,
    this.showWatermark = true,
  });

  @override
  State<_AssetFullscreenViewer> createState() => _AssetFullscreenViewerState();
}

class _AssetFullscreenViewerState extends State<_AssetFullscreenViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    ScreenSecureUtil.enable();
  }

  @override
  void dispose() {
    ScreenSecureUtil.disable();
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
        title: Text(widget.images[_currentIndex]['label'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.asset(widget.images[index]['path']!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_outlined, color: Colors.white38, size: 60)),
              ),
            ),
          ),
          if (widget.showWatermark)
            Positioned.fill(
              child: IgnorePointer(child: _WatermarkOverlay()),
            ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.images.asMap().entries.map((entry) {
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

class _WatermarkOverlay extends StatelessWidget {
  const _WatermarkOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WatermarkPainter(), child: Container());
  }
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    canvas.save();
    canvas.rotate(-0.45);

    const spacingX = 220.0;
    const spacingY = 90.0;
    final cols = (size.width * 1.5 / spacingX).ceil() + 2;
    final rows = (size.height * 1.5 / spacingY).ceil() + 2;

    for (int row = -2; row < rows; row++) {
      for (int col = -2; col < cols; col++) {
        final x = col * spacingX + (row.isEven ? 0 : spacingX / 2);
        final y = row * spacingY;
        final text = row.isEven ? '© 미리톡  무단캡처금지' : '저작권법 위반 시 법적 책임';
        textPainter.text = TextSpan(
          text: text,
          style: const TextStyle(
              color: Color(0x12FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();

    final warningRect = Rect.fromLTWH(0, size.height - 52, size.width, 52);
    canvas.drawRect(warningRect,
        Paint()..color = Colors.black.withValues(alpha: 0.65));

    final warningPainter = TextPainter(
      text: const TextSpan(children: [
        TextSpan(text: '⚠️  ', style: TextStyle(fontSize: 12)),
        TextSpan(
          text: '본 이미지는 저작권법의 보호를 받습니다.\n',
          style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
        TextSpan(
          text: '무단 캡처·배포 시 민·형사상 책임이 발생할 수 있습니다.',
          style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11),
        ),
      ]),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: TextAlign.center,
    );

    warningPainter.layout(maxWidth: size.width - 32);
    warningPainter.paint(
      canvas,
      Offset(
        (size.width - warningPainter.width) / 2,
        size.height - 52 + (52 - warningPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 태그 뱃지 ────────────────────────────────────────
class _TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TagBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5, height: 5,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── 증거 사진 썸네일 ──────────────────────────────────
class _EvidencePhoto extends StatelessWidget {
  final String imagePath;
  final String label;
  final List<Map<String, String>> allImages;
  final int initialIndex;
  final bool showZoom;

  const _EvidencePhoto({
    required this.imagePath,
    required this.label,
    required this.allImages,
    required this.initialIndex,
    this.showZoom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _AssetFullscreenViewer(
              images: allImages, initialIndex: initialIndex),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.surfaceDeep,
                    child: const Icon(Icons.image_outlined,
                        color: AppTheme.primary, size: 24))),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.photoLabelBg,
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
            if (showZoom)
              Positioned(
                top: 5, right: 5,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.overlayMedium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.zoom_in,
                      color: Colors.white70, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 인기 분석 티커 ────────────────────────────────────
class _FeedTicker extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool useApiData;
  final VoidCallback onTap;

  const _FeedTicker({
    required this.items,
    required this.onTap,
    this.useApiData = false,
  });

  @override
  State<_FeedTicker> createState() => _FeedTickerState();
}

class _FeedTickerState extends State<_FeedTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideOut;
  late Animation<Offset> _slideIn;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideIn = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _startTicker();
  }

  void _startTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      await _controller.forward();
      if (!mounted) return false;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.items.length;
      });
      _controller.reset();
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // API 데이터 파싱 헬퍼
  bool _isHigh(Map<String, dynamic> item) {
    if (widget.useApiData) {
      return ['높음', '매우높음'].contains(item['riskLevel'] as String? ?? '');
    }
    return item['isHigh'] as bool;
  }

  int _riskPct(Map<String, dynamic> item) {
    if (widget.useApiData) return (item['riskScore'] as int? ?? 0);
    return item['riskPct'] as int;
  }

  String _text(Map<String, dynamic> item) {
    if (widget.useApiData) {
      final content = item['content'] as String? ?? '';
      return content.isNotEmpty ? content : (item['summary'] as String? ?? '');
    }
    return item['text'] as String;
  }

  int _likes(Map<String, dynamic> item) {
    if (widget.useApiData) return (item['likeCount'] as int? ?? 0);
    return item['likes'] as int;
  }

  void _onTap(BuildContext context) {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final nextItem = _currentIndex + 1 < widget.items.length
        ? widget.items[_currentIndex + 1]
        : widget.items[0];

    final isHigh = _isHigh(item);
    final nextIsHigh = _isHigh(nextItem);

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 라벨
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                          color: AppTheme.primary, shape: BoxShape.circle),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('인기 분석',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 10),
            Container(width: 0.5, height: 18, color: AppTheme.divider),
            const SizedBox(width: 10),

            // 슬라이드 영역
            Expanded(
              child: SizedBox(
                height: 20,
                child: ClipRect(
                  child: Stack(
                    children: [
                      SlideTransition(
                        position: _slideOut,
                        child: _TickerRow(
                          riskPct: _riskPct(item),
                          riskColor: isHigh ? AppTheme.riskHigh : AppTheme.riskMedium,
                          riskBg: isHigh ? AppTheme.tickerHighBg : AppTheme.tickerMediumBg,
                          isHigh: isHigh,
                          text: _text(item),
                          likes: _likes(item),
                        ),
                      ),
                      SlideTransition(
                        position: _slideIn,
                        child: _TickerRow(
                          riskPct: _riskPct(nextItem),
                          riskColor: nextIsHigh ? AppTheme.riskHigh : AppTheme.riskMedium,
                          riskBg: nextIsHigh ? AppTheme.tickerHighBg : AppTheme.tickerMediumBg,
                          isHigh: nextIsHigh,
                          text: _text(nextItem),
                          likes: _likes(nextItem),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickerRow extends StatelessWidget {
  final int riskPct;
  final Color riskColor;
  final Color riskBg;
  final bool isHigh;
  final String text;
  final int likes;

  const _TickerRow({
    required this.riskPct,
    required this.riskColor,
    required this.riskBg,
    required this.isHigh,
    required this.text,
    required this.likes,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: riskBg, borderRadius: BorderRadius.circular(4)),
            child: Text('${isHigh ? "위험" : "의심"} $riskPct%',
                style: TextStyle(
                    color: riskColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Text('♥ $likes',
              style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
        ],
      ),
    );
  }
}