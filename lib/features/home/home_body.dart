// lib/features/home/home_body.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class HomeBody extends StatefulWidget {
  final VoidCallback onGoToUpload;
  const HomeBody({super.key, required this.onGoToUpload});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  int _currentSlide = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  // 실제 사기 증거 이미지 경로 (assets에 추가 필요)
  final List<Map<String, String>> _evidenceImages = [
    {
      'path': 'assets/images/evidence_1.png',
      'label': '진정서',
    },
    {
      'path': 'assets/images/evidence_2.png',
      'label': '경찰 조사 메시지',
    },
    {
      'path': 'assets/images/evidence_3.png',
      'label': '사기 피해 대화',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 40), // 좌우 20→12, 상단 24→16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 스토리 카드 ──
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
              border: Border.all(
                color: AppTheme.primary.withValues(alpha:0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 뱃지
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified,
                              color: AppTheme.primary, size: 13),
                          SizedBox(width: 4),
                          Text(
                            '실제 피해 경험 기반 AI',
                            style: TextStyle(
                                color: AppTheme.primary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.success.withValues(alpha:0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.favorite,
                              color: Colors.red, size: 13),
                          SizedBox(width: 4),
                          Text(
                            '완전 무료',
                            style: TextStyle(
                                color: AppTheme.success, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 텍스트 + 이미지 슬라이더 가로 배치
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 좌측 텍스트
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

                    // 우측 이미지 슬라이더
                    Column(
                      children: [
                        // CarouselSlider 부분을 SizedBox로 감싸기
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
                                onPageChanged: (index, _) {
                                  setState(() => _currentSlide = index);
                                },
                              ),
                              items: _evidenceImages.map((item) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      item['path']!,
                                      width: 110,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 110,
                                        height: 110,
                                        color: AppTheme.surface,
                                        child: const Icon(
                                          Icons.image_outlined,
                                          color: AppTheme.primary,
                                          size: 32,
                                        ),
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
                                              Colors.black.withValues(alpha:0.7),
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

                        // 슬라이드 인디케이터 점
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _evidenceImages.asMap().entries.map((entry) {
                            return GestureDetector(
                              onTap: () =>
                                  _carouselController.animateToPage(entry.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _currentSlide == entry.key ? 16 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: _currentSlide == entry.key
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

          // ── 사용 방법 안내 ──
          const Text(
            '이렇게 사용하세요',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
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

          const SizedBox(height: 16),

          // ── 분석 시작 버튼 ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onGoToUpload,
              icon: const Icon(Icons.shield_outlined, color: Colors.white),
              label: const Text(
                '지금 바로 사기 분석하기',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
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

// ── 단계 안내 카드 ─────────────────────────────────
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
        border: Border.all(color: Colors.white.withValues(alpha:0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha:0.15),
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
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}