// lib/features/home/home_body.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show Random;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/tracking/screen_time_tracker.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';
import 'package:miritalk_app/core/utils/screen_secure_util.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'package:miritalk_app/features/community/community_screen.dart';
import 'package:miritalk_app/features/home/analysis_quota_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

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

  List<Map<String, dynamic>> _rankingPosts = [];
  bool _rankingLoading = true;

  final List<Map<String, String>> _evidenceImages = [
    {'path': 'assets/images/evidence_4.jpg', 'label': '사기접수 및 검거'},
    {'path': 'assets/images/evidence_3.jpg', 'label': '사기 피해 대화'},
    {'path': 'assets/images/evidence_1.jpg', 'label': '진정서 작성'},
    {'path': 'assets/images/evidence_2.jpg', 'label': '경찰 조사'},
  ];

  @override
  void initState() {
    super.initState();
    _tracker = ScreenTimeTracker('home');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQuotaIfLoggedIn();
    });
    _loadRanking();
  }

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
  void dispose() {
    _tracker.dispose();
    if (_listenerAttached) _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _loadRanking() async {
    debugPrint('[Ranking] /api/community/ranking 호출 시작');
    try {
      final response = await ApiClient().get('/api/community/ranking');
      debugPrint('[Ranking] 응답 status=${response.statusCode} '
          'body_len=${response.bodyBytes.length}');
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      debugPrint('[Ranking] 파싱 결과 ${list.length}건');
      if (mounted) {
        setState(() {
          _rankingPosts =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _rankingLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[Ranking] 오류: $e\n$st');
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
  }

  void _showGuestQuotaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('분석 횟수 소진',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        ]),
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
        title: const Row(children: [
          Icon(Icons.block, color: AppTheme.danger, size: 20),
          SizedBox(width: 8),
          Text('오늘 분석 횟수 초과',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        ]),
        content: Text(
          '오늘 분석 횟수($max회)를 모두 사용했습니다.\n내일 자정에 횟수가 초기화됩니다.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final quota = context.watch<AnalysisQuotaProvider>();

    // 가짜 fallback 을 쓰지 않고 실제 랭킹이 있을 때만 ticker 렌더 → 커뮤니티 화면과 데이터 일치
    final tickerItems = _rankingPosts;
    final useApiData = !_rankingLoading && _rankingPosts.isNotEmpty;

    final isExhausted = quota.isExhausted;
    final isGuest = !auth.isLoggedIn;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16, 14, 16,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Hero Pitch — 헤드라인 + What/How + CTA + 쿼터 (첫 fold 안에 모두) ──
          _HeroPitchCard(
            used: quota.usedCount,
            max: quota.maxCount,
            isGuest: isGuest,
            isExhausted: isExhausted,
            onTap: () => _onAnalysisTap(context),
          ),

          const SizedBox(height: 24),

          // ── 2. 사용 방법 (사용법 먼저) ──
          const _SectionTitle(
            overline: '사용 방법',
            title: '3단계면 충분해요',
          ),
          const SizedBox(height: 14),
          const _StepList(),

          const SizedBox(height: 24),

          // ── 3. 카테고리 ──
          const _SectionTitle(
            overline: '카테고리',
            title: '이런 사기를 사전에 탐지합니다',
          ),
          const SizedBox(height: 14),
          const _CategoryRow(),

          const SizedBox(height: 24),

          // ── 4. WHY 미리톡 — 운영자 스토리 + 증거 사진 + 인기 분석 ──
          _WhyMiritalkSection(
            evidenceImages: _evidenceImages,
            tickerItems: tickerItems,
            useApiData: useApiData,
            rankingPosts: _rankingPosts,
            rankingLoading: _rankingLoading,
            onReturnFromCommunity: _loadRanking,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Why 미리톡 Section — 운영자 스토리 + 증거 사진 + 인기 분석
// ══════════════════════════════════════════════════════════════
class _WhyMiritalkSection extends StatelessWidget {
  final List<Map<String, String>> evidenceImages;
  final List<Map<String, dynamic>> tickerItems;
  final bool useApiData;
  final List<Map<String, dynamic>> rankingPosts;
  final bool rankingLoading;
  final VoidCallback? onReturnFromCommunity;

  const _WhyMiritalkSection({
    required this.evidenceImages,
    required this.tickerItems,
    required this.useApiData,
    required this.rankingPosts,
    required this.rankingLoading,
    this.onReturnFromCommunity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          overline: 'WHY 미리톡',
          title: '실제 피해 경험으로 만들었어요',
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.08),
                  AppTheme.surface,
                ],
              ),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                // ── ambient glow ──
                Positioned(
                  top: -60, right: -40,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 운영자 스토리 ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 헤드라인
                          const Text(
                            '사기를 당하다 보니',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              letterSpacing: -0.03 * 22,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFBDB0FF), Color(0xFF9B87F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              '전문가가 됐습니다.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                                letterSpacing: -0.03 * 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '직접 겪은 수백 건의 사기 경험을 AI 로직에 담았어요.\n실제 사례 패턴 기반으로 분석합니다.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.7,
                              letterSpacing: -0.01 * 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                // ── evidence collage ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: SizedBox(
                    height: 126,
                    child: Row(
                      children: [
                        // large left photo
                        Expanded(
                          flex: 2,
                          child: _EvidencePhoto(
                            imagePath: evidenceImages[0]['path']!,
                            label: evidenceImages[0]['label']!,
                            allImages: evidenceImages,
                            initialIndex: 0,
                            showZoom: true,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // small right column
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              Expanded(child: _EvidencePhoto(
                                imagePath: evidenceImages[1]['path']!,
                                label: evidenceImages[1]['label']!,
                                allImages: evidenceImages,
                                initialIndex: 1,
                              )),
                              const SizedBox(height: 5),
                              Expanded(child: _EvidencePhoto(
                                imagePath: evidenceImages[2]['path']!,
                                label: evidenceImages[2]['label']!,
                                allImages: evidenceImages,
                                initialIndex: 2,
                              )),
                              const SizedBox(height: 5),
                              Expanded(child: _EvidencePhoto(
                                imagePath: evidenceImages[3]['path']!,
                                label: evidenceImages[3]['label']!,
                                allImages: evidenceImages,
                                initialIndex: 3,
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── popular ticker ──
                // 로딩 중: "준비 중" placeholder. 완료 후 비면 섹션 전체 숨김.
                if (rankingLoading || tickerItems.isNotEmpty) ...[
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: AppTheme.divider,
                  ),
                  if (rankingLoading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 12, 18, 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 10, height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppTheme.primary),
                          ),
                          SizedBox(width: 8),
                          Text('인기 분석 불러오는 중...',
                              style: TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    )
                  else
                    _FeedTicker(
                      items: tickerItems,
                      useApiData: useApiData,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityScreen(
                              preloadedRanking: rankingPosts.isNotEmpty
                                  ? rankingPosts
                                      .map((e) => CommunityPost.fromJson(e))
                                      .toList()
                                  : null,
                            ),
                          ),
                        );
                        // 커뮤니티에서 좋아요/새 글이 생겼을 수 있으니 랭킹 재조회
                        onReturnFromCommunity?.call();
                      },
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Section Title (overline + title)
// ══════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String overline;
  final String title;
  final Widget? trailing;

  const _SectionTitle({
    required this.overline,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              overline.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primary, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Quota Strip (with progress bar)
// ══════════════════════════════════════════════════════════════
class _QuotaStrip extends StatelessWidget {
  final int used;
  final int max;
  final bool isGuest;

  const _QuotaStrip({
    required this.used,
    required this.max,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = max - used;
    final pct = max > 0 ? used / max : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 14),
              const SizedBox(width: 8),
              Text(
                isGuest ? '게스트 무료 분석' : '오늘 남은 분석',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: -0.01 * 12,
                ),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$remaining',
                      style: const TextStyle(
                        color: Color(0xFFBDB0FF),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' / $max',
                      style: const TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 3,
              color: AppTheme.surfaceDeep,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (1.0 - pct).clamp(0.0, 1.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, Color(0xFFBDB0FF)],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Primary CTA (gradient button)
// ══════════════════════════════════════════════════════════════
class _PrimaryCTA extends StatelessWidget {
  final bool isExhausted;
  final bool isGuest;
  final VoidCallback onTap;

  const _PrimaryCTA({
    required this.isExhausted,
    required this.isGuest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = isGuest && isExhausted;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: locked
              ? [AppTheme.primary.withValues(alpha: 0.5), AppTheme.primaryDeep.withValues(alpha: 0.5)]
              : [AppTheme.primary, AppTheme.primaryDeep],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                locked ? Icons.lock_outline : Icons.shield_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                locked ? '로그인하고 계속 분석하기' : '지금 바로 사기 분석하기',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02 * 16,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white70, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Category Row
// ══════════════════════════════════════════════════════════════
class _CategoryRow extends StatelessWidget {
  const _CategoryRow();

  static const _cats = [
    (icon: Icons.storefront_outlined, color: Color(0xFF4FC3F7), title: '중고거래 사기', desc: '입금 후 잠적·미배송'),
    (icon: Icons.trending_up,         color: Color(0xFF81C784), title: '투자 사기',    desc: '고수익 미끼로 유도'),
    (icon: Icons.sports_esports_outlined, color: Color(0xFFEF9A9A), title: '게임 사기', desc: '아이템 거래 후 잠적'),
    (icon: Icons.phone_outlined,      color: Color(0xFFCE93D8), title: '보이스피싱',   desc: '기관 사칭으로 송금'),
    (icon: Icons.work_outline,        color: Color(0xFFFFB74D), title: '취업 사기',    desc: '허위 채용으로 탈취'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = _cats[i];
          return Container(
            constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,                              // 단색 서피스
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.color.withValues(alpha: 0.15), width: 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(c.icon, color: c.color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  c.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  c.desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 8,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Step List
// ══════════════════════════════════════════════════════════════
class _StepList extends StatelessWidget {
  const _StepList();

  static const _steps = [
    (n: 1, icon: Icons.chat_bubble_outline, title: '대화 화면 캡처',
    desc: '의심되는 상대방과의 대화 내용을 캡처해 주세요.',
    imagePath: 'assets/images/step_capture.jpg', videoPath: null),
    (n: 2, icon: Icons.upload_outlined, title: '사진 업로드',
    desc: '캡처한 사진을 최대 5장까지 업로드합니다.',
    imagePath: null, videoPath: 'assets/videos/step_upload.mp4'),
    (n: 3, icon: Icons.analytics_outlined, title: 'AI 분석',
    desc: '미리톡 AI가 사기 패턴을 분석하고 결과를 알려드립니다.',
    imagePath: null, videoPath: 'assets/videos/step_result.mp4'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _steps.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _StepItem(
            n: s.n,
            icon: s.icon,
            title: s.title,
            desc: s.desc,
            imagePath: s.imagePath,
            videoPath: s.videoPath,
          ),
        );
      }).toList(),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int n;
  final IconData icon;
  final String title;
  final String desc;
  final String? imagePath;
  final String? videoPath;

  const _StepItem({
    required this.n,
    required this.icon,
    required this.title,
    required this.desc,
    required this.imagePath,
    required this.videoPath,
  }) : assert(imagePath != null || videoPath != null,
            'imagePath 또는 videoPath 중 하나는 반드시 지정해야 한다');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        children: [
          // STEP N badge
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'STEP',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 7,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '$n',
                  style: const TextStyle(
                    color: Color(0xFFBDB0FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.textHint, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.02 * 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // thumbnail (video or image)
          if (videoPath != null)
            _StepVideo(videoPath: videoPath!, title: title)
          else
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.divider,
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset(
                        imagePath!,
                        width: 56, height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.surfaceDeep,
                          child: const Icon(Icons.image_outlined,
                              color: AppTheme.primary, size: 22),
                        ),
                      ),
                    ),
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Step Video (auto-play, loop, mute — GIF 대체)
// ══════════════════════════════════════════════════════════════
class _StepVideo extends StatefulWidget {
  final String videoPath;
  final String title;
  const _StepVideo({required this.videoPath, required this.title});

  @override
  State<_StepVideo> createState() => _StepVideoState();
}

class _StepVideoState extends State<_StepVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..setLooping(true)
      ..setVolume(0)
      ..addListener(_onControllerChanged);
    _controller.initialize().then((_) {
      if (!mounted) return;
      developer.log(
        'video initialized: ${widget.videoPath} '
        'size=${_controller.value.size} '
        'duration=${_controller.value.duration}',
        name: 'StepVideo',
      );
      _controller.play();
      setState(() => _ready = true);
    }).catchError((Object e, StackTrace st) {
      developer.log(
        'video init failed: ${widget.videoPath}',
        name: 'StepVideo',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    });
  }

  void _onControllerChanged() {
    final err = _controller.value.errorDescription;
    if (err != null && _errorMessage == null) {
      developer.log('video player error: $err',
          name: 'StepVideo');
      if (!mounted) return;
      setState(() => _errorMessage = err);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready || _errorMessage != null) return;
    if (state == AppLifecycleState.resumed && !_controller.value.isPlaying) {
      _controller.play();
    }
  }

  Future<void> _openFullscreen() async {
    // 풀스크린이 위에 올라가 있는 동안은 썸네일 정지 (리소스 절약 + 같은 asset 충돌 방지)
    await _controller.pause();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _VideoFullscreenViewer(
          videoPath: widget.videoPath,
          title: widget.title,
        ),
      ),
    );
    if (!mounted || _errorMessage != null) return;
    _controller.play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _controller.value.size;
    final hasValidSize = size.width > 0 && size.height > 0;

    return GestureDetector(
      onTap: _ready ? _openFullscreen : null,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDeep,
                border: Border.all(color: AppTheme.divider, width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _errorMessage != null
                  ? const Icon(Icons.videocam_off_outlined,
                      color: AppTheme.primary, size: 22)
                  : (_ready && hasValidSize)
                      ? FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: VideoPlayer(_controller),
                          ),
                        )
                      : const Center(
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textHint,
                            ),
                          ),
                        ),
            ),
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
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Video Fullscreen Viewer
// ══════════════════════════════════════════════════════════════
class _VideoFullscreenViewer extends StatefulWidget {
  final String videoPath;
  final String title;
  const _VideoFullscreenViewer({
    required this.videoPath,
    required this.title,
  });

  @override
  State<_VideoFullscreenViewer> createState() => _VideoFullscreenViewerState();
}

class _VideoFullscreenViewerState extends State<_VideoFullscreenViewer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..setLooping(true)
      ..setVolume(0);
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.play();
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.white70),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Trust Footer
// ══════════════════════════════════════════════════════════════
class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  static const _items = [
    (icon: Icons.lock_outline,     label: '업로드 사진\n분석 전용'),
    (icon: Icons.verified_outlined, label: 'AI 학습\n미활용'),
    (icon: Icons.auto_awesome,     label: '실제 사례\n기반 분석'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _items.map((it) {
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.divider,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(it.icon,
                      color: const Color(0xFFBDB0FF), size: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  it.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    height: 1.5,
                    letterSpacing: -0.01 * 10,
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

// ══════════════════════════════════════════════════════════════
// Feed Ticker (Popular Analysis)
// ══════════════════════════════════════════════════════════════
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
            // label
            Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('인기 분석',
                    style: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(width: 10),
            Container(width: 0.5, height: 14, color: AppTheme.divider),
            const SizedBox(width: 10),

            // sliding area
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
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                color: AppTheme.textHint, size: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: riskBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${isHigh ? "위험" : "의심"} $riskPct%',
              style: TextStyle(
                color: riskColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                letterSpacing: -0.01 * 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '♥ $likes',
            style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Tag Badge
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// Evidence Photo Thumbnail
// ══════════════════════════════════════════════════════════════
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
            images: allImages,
            initialIndex: initialIndex,
          ),
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
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                  borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
            if (showZoom)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.remove_red_eye_outlined,
                          color: Colors.white, size: 11),
                      SizedBox(width: 3),
                      Text('탭해서 보기',
                          style:
                          TextStyle(color: Colors.white, fontSize: 9)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Fullscreen Image Viewer (unchanged logic)
// ══════════════════════════════════════════════════════════════
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
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.asset(
                  widget.images[index]['path']!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_outlined,
                      color: Colors.white38,
                      size: 60),
                ),
              ),
            ),
          ),
          if (widget.showWatermark)
            Positioned.fill(
              child: IgnorePointer(child: _WatermarkOverlay()),
            ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 24 + MediaQuery.of(context).padding.bottom,
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

    final warningRect =
    Rect.fromLTWH(0, size.height - 52, size.width, 52);
    canvas.drawRect(
        warningRect, Paint()..color = Colors.black.withValues(alpha: 0.65));

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

class _TrustTooltipButton extends StatefulWidget {
  const _TrustTooltipButton();

  @override
  State<_TrustTooltipButton> createState() => _TrustTooltipButtonState();
}

class _TrustTooltipButtonState extends State<_TrustTooltipButton> {
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _overlay;

  static const _items = [
    (icon: Icons.lock_outline,      label: '업로드 사진\n분석 전용'),
    (icon: Icons.verified_outlined, label: 'AI 학습\n미활용'),
    (icon: Icons.auto_awesome,      label: '실제 사례\n기반 분석'),
  ];

  void _show() {
    final renderBox =
    _btnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final btnSize = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;

    // 버튼 우측 끝 기준으로 툴팁 우측 정렬, 버튼 아래 8px 간격
    final rightEdge = screenWidth - (offset.dx + btnSize.width);

    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 바깥 탭 시 닫기
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          // 툴팁 카드
          Positioned(
            top: offset.dy + btnSize.height + 8,
            right: rightEdge,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 216,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더
                    Row(children: const [
                      Icon(Icons.shield_outlined,
                          color: AppTheme.primary, size: 13),
                      SizedBox(width: 5),
                      Text(
                        '미리톡 보안 정책',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    // 아이템 3개
                    Row(
                      children: _items.map((it) {
                        return Expanded(
                          child: Column(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Icon(it.icon,
                                  color: const Color(0xFFBDB0FF), size: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              it.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlay!);
    setState(() {}); // 토글 상태 반영
  }

  void _dismiss() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _overlay == null ? _show : _dismiss,
      child: Container(
        key: _btnKey,
        width: 22, height: 22,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: (_overlay != null)
              ? AppTheme.primary.withValues(alpha: 0.25) // 열림 상태 강조
              : AppTheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3), width: 0.5),
        ),
        child: const Icon(Icons.security,
            color: AppTheme.primary, size: 13),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 오늘 분석 모의 카운터 — 날짜 시드로 매일 다른 곡선
// 오전(0~12시): 1 → morningPeak(4~10) 점진 증가
// 오후(12~24시): morningPeak → afternoonPeak(15~30) 점진 증가
// 실제 사용자 늘면 /api/fraud/today-count 같은 엔드포인트로 한 줄만 교체
// ══════════════════════════════════════════════════════════════
int _todayMockCount() {
  final now = DateTime.now();
  final dateSeed = now.year * 10000 + now.month * 100 + now.day;
  final rng = Random(dateSeed);

  final morningPeak = 4 + rng.nextInt(7);     // 4 ~ 10
  final afternoonPeak = 15 + rng.nextInt(16); // 15 ~ 30

  final hour = now.hour;
  final minute = now.minute;

  if (hour < 12) {
    final progress = (hour * 60 + minute) / (12 * 60);
    return (1 + (morningPeak - 1) * progress).round().clamp(1, 10);
  } else {
    final progress = ((hour - 12) * 60 + minute) / (12 * 60);
    return (morningPeak + (afternoonPeak - morningPeak) * progress)
        .round()
        .clamp(10, 30);
  }
}

// ══════════════════════════════════════════════════════════════
// Live Count Badge — Hero 우측에 붙는 작은 라이브 카운터
// 표시값 = 시드 기반 베이스(mockCount) + 서버에서 받은 오늘 실제 분석 건수
// ══════════════════════════════════════════════════════════════
class _LiveCountBadge extends StatefulWidget {
  final int mockCount;
  // quota.usedCount 등 외부 트리거 — 값이 변하면 서버 카운트 재조회
  final int refetchTrigger;
  const _LiveCountBadge({
    required this.mockCount,
    this.refetchTrigger = 0,
  });

  @override
  State<_LiveCountBadge> createState() => _LiveCountBadgeState();
}

class _LiveCountBadgeState extends State<_LiveCountBadge> {
  int _serverCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchServerCount();
  }

  @override
  void didUpdateWidget(covariant _LiveCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 본인이 분석 후 홈 복귀 → quota.usedCount 변경 → 자동 재조회
    if (oldWidget.refetchTrigger != widget.refetchTrigger) {
      _fetchServerCount();
    }
  }

  Future<void> _fetchServerCount() async {
    try {
      final response = await ApiClient().get('/api/fraud/today-count');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) {
        setState(() => _serverCount = json['count'] as int? ?? 0);
      }
    } catch (_) {
      // 서버 실패 시 mockCount만 표시 (사용자에겐 보이지 않음)
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.mockCount + _serverCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.28),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _PulseDot(color: AppTheme.danger, size: 6),
              SizedBox(width: 4),
              Text(
                '실시간',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFFBDB0FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '건',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            '오늘 분석',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 9,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Pulse Dot — 천천히 깜빡이는 라이브 인디케이터
// ══════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulseDot({required this.color, required this.size});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Hero Pitch Card — 첫 fold 안에 What/How/Action 모두 노출
// ══════════════════════════════════════════════════════════════
class _HeroPitchCard extends StatelessWidget {
  final int used;
  final int max;
  final bool isGuest;
  final bool isExhausted;
  final VoidCallback onTap;

  const _HeroPitchCard({
    required this.used,
    required this.max,
    required this.isGuest,
    required this.isExhausted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primary.withValues(alpha: 0.12),
              AppTheme.surface,
            ],
          ),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Stack(
          children: [
            // ambient glow
            Positioned(
              top: -60, right: -40,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 신뢰 배지 ──
                  Row(
                    children: [
                      _TagBadge(
                          label: '실제 피해 경험 기반',
                          color: AppTheme.primary),
                      const SizedBox(width: 6),
                      _TagBadge(label: '무료', color: AppTheme.success),
                      const Spacer(),
                      const _TrustTooltipButton(),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── 헤드라인 + 부제 / 우측 라이브 카운터 + 위험도 예시 ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '속기 전에,',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                letterSpacing: -0.03 * 24,
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFBDB0FF),
                                  Color(0xFF9B87F5)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                '먼저 확인하세요.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                  letterSpacing: -0.03 * 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '보이스피싱·중고거래·투자 사기,\n'
                              '의심되는 대화 캡처 한 장으로\n'
                              'AI가 30초 만에 판단해드립니다.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                height: 1.7,
                                letterSpacing: -0.01 * 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _LiveCountBadge(
                        mockCount: _todayMockCount(),
                        refetchTrigger: used, // quota.usedCount 변화 시 재조회
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── CTA ──
                  _PrimaryCTA(
                    isExhausted: isExhausted,
                    isGuest: isGuest,
                    onTap: onTap,
                  ),

                  const SizedBox(height: 10),

                  // ── 쿼터 (CTA 아래 작게) ──
                  _QuotaStrip(
                    used: used,
                    max: max,
                    isGuest: isGuest,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}