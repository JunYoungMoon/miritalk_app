// lib/features/home/home_body.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'package:miritalk_app/features/home/analysis_quota_provider.dart';

class HomeBody extends StatefulWidget {
  final VoidCallback onGoToUpload;
  const HomeBody({super.key, required this.onGoToUpload});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
  CarouselSliderController();

  final List<Map<String, String>> _evidenceImages = [
    {'path': 'assets/images/evidence_1.png', 'label': '진정서'},
    {'path': 'assets/images/evidence_2.png', 'label': '경찰 조사 메시지'},
    {'path': 'assets/images/evidence_3.png', 'label': '사기 피해 대화'},
  ];

  Future<void> _onAnalysisTap(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final quota = context.read<AnalysisQuotaProvider>();
    await quota.loadQuota();
    if (!context.mounted) return;
    if (quota.isExhausted) {
      _showQuotaDialog(context, quota.usedCount, quota.maxCount);
      return;
    }
    widget.onGoToUpload();
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
          '오늘 무료 분석 횟수($max회)를 모두 사용했습니다.\n내일 자정에 횟수가 초기화됩니다.',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 40),
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
              border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: AppTheme.primaryBadgeDecoration(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified,
                                  color: AppTheme.primary, size: 13),
                              SizedBox(width: 4),
                              Text('실제 피해 경험 기반 AI',
                                  style: TextStyle(
                                      color: AppTheme.primary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: AppTheme.successBadgeDecoration(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, color: Colors.red, size: 13),
                              SizedBox(width: 4),
                              Text('완전 무료',
                                  style: TextStyle(
                                      color: AppTheme.success, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '사기 당하다 보니\n전문가가 됐습니다.',
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
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CarouselSlider(
                              carouselController: _carouselController,
                              options: CarouselOptions(
                                height: 110,
                                viewportFraction: 1.0,
                                autoPlay: true,
                                autoPlayInterval: const Duration(seconds: 3),
                                autoPlayCurve: Curves.easeInOut,
                                onPageChanged: (index, _) =>
                                    setState(() => _currentSlide = index),
                              ),
                              items: _evidenceImages.map((item) {
                                return Stack(
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black
                                                  .withValues(alpha: 0.7),
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
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _evidenceImages.asMap().entries.map((e) {
                            return GestureDetector(
                              onTap: () =>
                                  _carouselController.animateToPage(e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _currentSlide == e.key ? 16 : 6,
                                height: 6,
                                margin:
                                const EdgeInsets.symmetric(horizontal: 2),
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
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 2. 통계 뱃지 ──
          // const _StatsBadges(),

          // const SizedBox(height: 20),

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
          ),
          const SizedBox(height: 10),
          const _StepCard(
            step: '2',
            icon: Icons.upload_outlined,
            title: '사진 업로드',
            description: '캡처한 사진을 최대 5장까지 업로드합니다.',
          ),
          const SizedBox(height: 10),
          const _StepCard(
            step: '3',
            icon: Icons.analytics_outlined,
            title: 'AI 분석',
            description: '미리톡 AI가 사기 패턴을 분석하고 결과를 알려드립니다.',
          ),

          const SizedBox(height: 20),

          // ── 5. 분석 결과 예시 ──
          // const _SampleResultCard(),

          // const SizedBox(height: 16),

          // ── 6. 잔여 횟수 뱃지 (로그인 시만) ──
          if (auth.isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuotaBadge(
                used: quota.usedCount,
                max: quota.maxCount,
              ),
            ),

          // ── 7. 분석 시작 버튼 ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _onAnalysisTap(context),
              icon: Icon(
                auth.isLoggedIn ? Icons.shield_outlined : Icons.lock_outline,
                color: Colors.white,
              ),
              label: Text(
                auth.isLoggedIn ? '지금 바로 사기 분석하기' : '로그인 후 사기 분석하기',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: auth.isLoggedIn
                    ? AppTheme.primary
                    : AppTheme.primary.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 통계 뱃지 ─────────────────────────────────────────
class _StatsBadges extends StatelessWidget {
  const _StatsBadges();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(
          icon: Icons.analytics_outlined,
          value: '1,200+',
          label: '누적 분석',
          color: AppTheme.primary,
        ),
        const SizedBox(width: 8),
        _StatItem(
          icon: Icons.gpp_bad_outlined,
          value: '94%',
          label: '탐지 정확도',
          color: AppTheme.danger,
        ),
        const SizedBox(width: 8),
        _StatItem(
          icon: Icons.people_outline,
          value: '100건+',
          label: '피해 경험 기반',
          color: AppTheme.success,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
            ),
          ],
        ),
      ),
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
    icon: Icons.work_outline,
    color: Color(0xFFFFB74D),
    title: '취업 사기',
    desc: '허위 채용으로\n개인정보 탈취',
    ),
    (
    icon: Icons.phone_outlined,
    color: Color(0xFFCE93D8),
    title: '보이스피싱',
    desc: '기관 사칭으로\n송금 유도',
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
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final t = _types[index];
              return Container(
                width: 90,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon, color: t.color, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      t.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
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

// ── 분석 결과 예시 ────────────────────────────────────
class _SampleResultCard extends StatelessWidget {
  const _SampleResultCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이런 결과를 받아보세요',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '사기 확률',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '위험 87%',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.87,
                  backgroundColor: AppTheme.surfaceDeep,
                  color: AppTheme.danger,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              const Text(
                '탐지된 의심 패턴',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _PatternChip(
                      label: '긴급함 유도', color: AppTheme.danger),
                  _PatternChip(
                      label: '감정 조작',
                      color: const Color(0xFFFFB74D)),
                  _PatternChip(
                      label: '신원 불명확',
                      color: const Color(0xFFFFB74D)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              const Text(
                '권장 행동',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const _ActionRow(
                icon: Icons.block,
                color: AppTheme.danger,
                text: '즉시 대화를 중단하세요',
              ),
              const SizedBox(height: 6),
              const _ActionRow(
                icon: Icons.local_police_outlined,
                color: AppTheme.primary,
                text: '경찰청 182에 신고하세요',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatternChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PatternChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ActionRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ── 잔여 횟수 뱃지 ────────────────────────────────────
class _QuotaBadge extends StatelessWidget {
  final int used;
  final int max;
  const _QuotaBadge({required this.used, required this.max});

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
                    ? '오늘 무료 분석 횟수를 모두 사용했습니다'
                    : '오늘 남은 분석 횟수',
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

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
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
                        color: Colors.white54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}