// lib/features/auth/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(
    BuildContext context,
    Future<void> Function() loginFn,
  ) async {
    await loginFn();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn && context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.security, size: 72, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    '미리톡 사기 방지 시스템',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '안전한 거래를 위한 서비스',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                  const SizedBox(height: 20),

                  // 온보딩 슬라이더
                  const _OnboardingSlider(),

                  const SizedBox(height: 20),

                  if (auth.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        auth.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),

                  _GoogleSignInButton(
                    isLoading: auth.isGoogleLoading,
                    onPressed: () =>
                        _handleLogin(context, () => auth.signInWithGoogle()),
                  ),
                  const SizedBox(height: 12),
                  _KakaoSignInButton(
                    isLoading: auth.isKakaoLoading,
                    onPressed: () =>
                        _handleLogin(context, () => auth.signInWithKakao()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 온보딩 슬라이더 ──────────────────────────────────
class _OnboardingSlider extends StatefulWidget {
  const _OnboardingSlider();

  @override
  State<_OnboardingSlider> createState() => _OnboardingSliderState();
}

class _OnboardingSliderState extends State<_OnboardingSlider> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _timer;

  static const _slides = [
    (
      imagePath: 'assets/images/onboarding_1.png', // 업로드 화면 스크린샷
      icon: Icons.upload_rounded,
      iconColor: Color(0xFF4FC3F7),
      tag: '1단계',
      title: '대화 캡처 업로드',
      desc: '카카오톡, 문자, 거래앱 등\n의심되는 대화를 캡처해서 올려주세요.',
    ),
    (
      imagePath: 'assets/images/onboarding_2.png', // 분석 중 화면 스크린샷
      icon: Icons.manage_search_rounded,
      iconColor: Color(0xFFCE93D8),
      tag: '2단계',
      title: 'AI 사기 패턴 분석',
      desc: '실제 100건 이상의 피해 경험을 학습한\nAI가 대화를 면밀하게 분석합니다.',
    ),
    (
      imagePath: 'assets/images/onboarding_3.png', // 분석 결과 화면 스크린샷
      icon: Icons.psychology_outlined,
      iconColor: Color(0xFFFFB74D),
      tag: '분석 결과',
      title: '심리 조작 기법 탐지',
      desc: '긴급함 유도, 감정 자극 등\n사기범의 심리 전술을 탐지합니다.',
    ),
    (
      imagePath: 'assets/images/onboarding_4.png', // 권장 행동 화면 스크린샷
      icon: Icons.tips_and_updates_outlined,
      iconColor: Color(0xFF81C784),
      tag: '대응 가이드',
      title: '맞춤 행동 지침 제공',
      desc: '즉시/단기 행동 지침과\n추가 확인 질문을 알려드립니다.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 슬라이드 카드
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final s = _slides[index];
              return _SlideCard(
                imagePath: s.imagePath,
                icon: s.icon,
                iconColor: s.iconColor,
                tag: s.tag,
                title: s.title,
                desc: s.desc,
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // 인디케이터 점
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _currentIndex == i ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _currentIndex == i ? AppTheme.primary : Colors.white24,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── 슬라이드 카드 ────────────────────────────────────
class _SlideCard extends StatelessWidget {
  final String imagePath;
  final IconData icon;
  final Color iconColor;
  final String tag;
  final String title;
  final String desc;

  const _SlideCard({
    required this.imagePath,
    required this.icon,
    required this.iconColor,
    required this.tag,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // 좌측 — 이미지 + 중앙 아이콘만
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 100,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imagePath.isNotEmpty
                      ? Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: iconColor.withValues(alpha: 0.1),
                    ),
                  )
                      : Container(color: iconColor.withValues(alpha: 0.1)),

                  // 하단 그라데이션
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 중앙 아이콘
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // 우측 — 아이콘+태그 묶음 + 타이틀 + 설명
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 아이콘 + 태그 묶음
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 14),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.5,
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

// ── 구글 로그인 버튼 ─────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.textPrimary,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Google로 계속하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

// ── 카카오 로그인 버튼 ───────────────────────────────
class _KakaoSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _KakaoSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFEE500),
        foregroundColor: const Color(0xFF391B1B),
        disabledBackgroundColor: const Color(0xFFFEE500).withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF391B1B),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_rounded,
                  color: Color(0xFF391B1B),
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  '카카오로 계속하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF391B1B),
                  ),
                ),
              ],
            ),
    );
  }
}
