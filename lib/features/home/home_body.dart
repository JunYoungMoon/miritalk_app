// lib/features/home/home_body.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'package:miritalk_app/features/home/analysis_quota_provider.dart';
import 'package:miritalk_app/features/home/widgets/scroll_hint_arrow.dart';
import 'package:miritalk_app/core/utils/screen_secure_util.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';
import 'package:miritalk_app/core/tracking/screen_time_tracker.dart';

class HomeBody extends StatefulWidget {
  final Future<void> Function() onGoToUpload;
  const HomeBody({super.key, required this.onGoToUpload});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  int _currentSlide = 0;
  bool _isBannerLoaded = false;
  late AuthProvider _authProvider;
  bool _listenerAttached = false;
  late final ScreenTimeTracker _tracker;

  final CarouselSliderController _carouselController =
  CarouselSliderController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _analyzeButtonKey = GlobalKey();
  bool _showScrollHint = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerAttached) {
      _authProvider = context.read<AuthProvider>();
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

  void _refreshQuotaIfLoggedIn() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    context
        .read<AnalysisQuotaProvider>()
        .loadQuota(isLoggedIn: auth.isLoggedIn);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _refreshQuotaIfLoggedIn();
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
    {'path': 'assets/images/evidence_1.jpg', 'label': '진정서 작성'},
    {'path': 'assets/images/evidence_2.jpg', 'label': '경찰 조사'},
    {'path': 'assets/images/evidence_3.jpg', 'label': '사기 피해 대화'},
    {'path': 'assets/images/evidence_4.jpg', 'label': '사기접수 및 검거'},
  ];

  Future<void> _onAnalysisTap(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final quota = context.read<AnalysisQuotaProvider>();

    if (!auth.isLoggedIn) {
      await quota.loadQuota(isLoggedIn: false);
      if (!context.mounted) return;

      if (quota.isExhausted) {
        // ── Analytics: 게스트 할당량 초과 ──
        TrackingService.instance.logQuotaExhausted(isGuest: true);
        _showGuestQuotaDialog(context);
        return;
      }

      await widget.onGoToUpload(); // 결과 화면까지 갔다가 돌아올 때까지 대기
      if (!context.mounted) return;
      await quota.loadQuota(isLoggedIn: false); // ← 돌아온 뒤 갱신
      return;
    }

    await quota.loadQuota(isLoggedIn: true);
    if (!context.mounted) return;

    if (quota.isExhausted) {
      // ── Analytics: 로그인 유저 할당량 초과 ──
      TrackingService.instance.logQuotaExhausted(isGuest: false);
      _showQuotaDialog(context, quota.usedCount, quota.maxCount);
      return;
    }

    await widget.onGoToUpload();
    if (!context.mounted) return;
    await quota.loadQuota(isLoggedIn: true); // 로그인 유저도 동일하게 갱신
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
            Text(
              '분석 횟수 소진',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          '비로그인 1회를 사용했습니다.\n로그인하면 매일 3회 분석할 수 있어요!',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              '로그인하기',
              style: TextStyle(color: AppTheme.primary),
            ),
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
            child:
            const Text('확인', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final quota = context.watch<AnalysisQuotaProvider>();

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
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.surfaceDeep, AppTheme.surface],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      height: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: AppTheme.primaryBadgeDecoration(),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified, color: AppTheme.primary, size: 13),
                                          SizedBox(width: 4),
                                          Flexible(
                                            child: Text('실제 피해 경험 기반 AI',
                                                style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      height: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: AppTheme.successBadgeDecoration(),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.favorite, color: Colors.red, size: 13),
                                          SizedBox(width: 4),
                                          Flexible(
                                            child: Text('완전 무료',
                                                style: TextStyle(color: AppTheme.success, fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '사기를 당하다 보니\n전문가가 됐습니다.',
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          height: 1.4,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        '이 경험, AI에게\n전부 학습시켰습니다.',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // ── 탭 안내 문구 ──
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.touch_app_outlined, color: AppTheme.textHint, size: 11),
                                        SizedBox(width: 3),
                                        Text(
                                          '탭하면 크게 볼 수 있어요',
                                          style: TextStyle(color: AppTheme.textHint, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // ── 캐러셀 (가로 확장) ──
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CarouselSlider(
                                        carouselController: _carouselController,
                                        options: CarouselOptions(
                                          height: 120,           // 110 → 120
                                          viewportFraction: 1.0,
                                          autoPlay: true,
                                          autoPlayInterval: const Duration(seconds: 3),
                                          autoPlayCurve: Curves.easeInOut,
                                          onPageChanged: (index, _) =>
                                              setState(() => _currentSlide = index),
                                        ),
                                        items: _evidenceImages.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final item = entry.value;
                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  fullscreenDialog: true,
                                                  builder: (_) => _AssetFullscreenViewer(
                                                    images: _evidenceImages,
                                                    initialIndex: index,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Image.asset(
                                                  item['path']!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: AppTheme.surface,
                                                    child: const Icon(Icons.image_outlined,
                                                        color: AppTheme.primary, size: 32),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.bottomCenter,
                                                        end: Alignment.topCenter,
                                                        colors: [
                                                          Colors.black.withValues(alpha: 0.7),
                                                          Colors.transparent,
                                                        ],
                                                      ),
                                                    ),
                                                    child: Text(
                                                      item['label']!,
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        color: AppTheme.textPrimary,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: Icon(
                                                    Icons.zoom_in,
                                                    color: Colors.white70,
                                                    size: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // ── 인디케이터 ──
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: _evidenceImages.asMap().entries.map((e) {
                                        return GestureDetector(
                                          onTap: () => _carouselController.animateToPage(e.key),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: _currentSlide == e.key ? 16 : 6,
                                            height: 6,
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(3),
                                              color: _currentSlide == e.key
                                                  ? AppTheme.primary
                                                  : Colors.white24,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 3. 사기 유형 카드 ──
                    const _FraudTypeCards(),

                    const SizedBox(height: 20),

                    // ── 4. 사용 방법 안내 ──
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

                    // ── 6. 잔여 횟수 뱃지 ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _QuotaBadge(
                        used: quota.usedCount,
                        max: quota.maxCount,
                        isGuest: quota.isGuest,
                      ),
                    ),

                    // ── 7. 분석 시작 버튼 ──
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

              // ── 스크롤 힌트 화살표 (Stack 위에 오버레이) ──
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

        // ── 하단 Banner 광고 ──
        // const BannerAdWidget(),
      ],
    );
  }
}

// ── 사기 유형 카드 ────────────────────────────────────
class _FraudTypeCards extends StatelessWidget {
  const _FraudTypeCards();

  static const _types = [
    (
    icon: Icons.storefront_outlined,
    color: Color(0xFF4FC3F7),
    title: '중고거래 사기',
    desc: '입금 후\n잠적·미배송',
    ),
    (
    icon: Icons.trending_up,
    color: Color(0xFF81C784),
    title: '투자 사기',
    desc: '고수익 미끼로\n투자 유도',
    ),
    (
    icon: Icons.sports_esports_outlined,
    color: Color(0xFFEF9A9A),
    title: '게임 아이템 사기',
    desc: '아이템 거래 후\n잠적·미지급',
    ),
    (
    icon: Icons.phone_outlined,
    color: Color(0xFFCE93D8),
    title: '보이스피싱',
    desc: '기관 사칭으로\n송금 유도',
    ),
    (
    icon: Icons.work_outline,
    color: Color(0xFFFFB74D),
    title: '취업 사기',
    desc: '허위 채용으로\n개인정보 탈취',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이런 사기를 사전에 탐지합니다',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115, // 100 → 110
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final t = _types[index];
              return Container(
                constraints: BoxConstraints(minWidth: 100, maxWidth: 120),
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
                    Text(
                      t.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 9,
                        height: 1.4,
                      ),
                    ),
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
  const _QuotaBadge({
    required this.used,
    required this.max,
    this.isGuest = false,
  });

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
          Row(
            children: [
              Icon(
                isExhausted ? Icons.block : Icons.analytics_outlined,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isExhausted
                    ? (isGuest
                    ? '로그인하면 매일 3회 분석할 수 있어요'
                    : '오늘 분석 횟수를 모두 사용했습니다')
                    : (isGuest ? '오늘 남은 분석 횟수' : '오늘 남은 분석 횟수'),
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
          if (!isExhausted)
            Text(
              '$remaining / $max',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // ── 스텝 번호 ──
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // ── 아이콘 ──
          Icon(icon, color: AppTheme.textHint, size: 20),
          const SizedBox(width: 10),
          // ── 텍스트 ──
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
                        color: Colors.white54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          // ── 오른쪽 이미지 ──
          if (imagePath != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => _AssetFullscreenViewer(
                      images: [{'path': imagePath!, 'label': title}],
                      initialIndex: 0,
                      showWatermark: false, // 스텝 이미지는 워터마크 없음
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      imagePath!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.image_outlined,
                            color: AppTheme.primary, size: 24),
                      ),
                    ),
                  ),
                  // 확대 힌트 아이콘
                  Positioned(
                    top: 3,
                    right: 3,
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

// 1. 풀스크린 뷰어 위젯 추가
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
        title: Text(
          widget.images[_currentIndex]['label'] ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── 이미지 페이지뷰 ──
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Image.asset(
                    widget.images[index]['path']!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_outlined,
                      color: Colors.white38,
                      size: 60,
                    ),
                  ),
                ),
              );
            },
          ),

          // ── 워터마크 오버레이 (포인터 이벤트 통과) ──
          if (widget.showWatermark)
            Positioned.fill(
              child: IgnorePointer(
                child: _WatermarkOverlay(),
              ),
            ),

          // ── 하단 인디케이터 ──
          if (widget.images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
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
    return CustomPaint(
      painter: _WatermarkPainter(),
      child: Container(), // CustomPaint가 Positioned.fill을 채우도록
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // 대각선으로 텍스트를 반복 배치
    final lines = [
      '© 미리톡  무단 캡처 금지',
      '저작권법 위반 시 민·형사상 책임',
    ];

    for (final line in lines) {
      textPainter.text = TextSpan(
        text: line,
        style: const TextStyle(
          color: Color(0x12FFFFFF), // 매우 연하게
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      );
      textPainter.layout(maxWidth: size.width);
    }

    // 대각선 패턴으로 전체 화면에 반복 출력
    canvas.save();
    canvas.rotate(-0.45); // 약 -25도 기울기

    const spacingX = 220.0;
    const spacingY = 90.0;
    final cols = (size.width * 1.5 / spacingX).ceil() + 2;
    final rows = (size.height * 1.5 / spacingY).ceil() + 2;

    for (int row = -2; row < rows; row++) {
      for (int col = -2; col < cols; col++) {
        final x = col * spacingX + (row.isEven ? 0 : spacingX / 2);
        final y = row * spacingY;

        // 홀수 행: 저작권 경고, 짝수 행: 앱 이름
        final text = row.isEven ? '© 미리톡  무단캡처금지' : '저작권법 위반 시 법적 책임';
        textPainter.text = TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0x12FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();

    // ── 하단 법적 경고 바 ──
    final warningRect = Rect.fromLTWH(0, size.height - 52, size.width, 52);
    canvas.drawRect(
      warningRect,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    final warningPainter = TextPainter(
      text: const TextSpan(
        children: [
          TextSpan(
            text: '⚠️  ',
            style: TextStyle(fontSize: 12),
          ),
          TextSpan(
            text: '본 이미지는 저작권법의 보호를 받습니다.\n',
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '무단 캡처·배포 시 민·형사상 책임이 발생할 수 있습니다.',
            style: TextStyle(
              color: Color(0xAAFFFFFF),
              fontSize: 11,
            ),
          ),
        ],
      ),
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