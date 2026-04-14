// lib/features/auth/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';

class LoginScreen extends StatefulWidget {
  final bool popAll;
  const LoginScreen({super.key, this.popAll = false});

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

  Future<void> _handleLogin(BuildContext context, Future<void> Function() loginFn, String method) async {

    // ── Analytics: 로그인 시도 ──
    TrackingService.instance.logLoginAttempt(method);

    await loginFn();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn && context.mounted) {
      // ── Analytics: 로그인 성공 ──
      TrackingService.instance.logLoginSuccess(method);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      // 상단 뒤로가기 버튼
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
          tooltip: '홈으로 돌아가기',
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                  Image.asset('assets/icons/app_icon5.png', width: 72, height: 72),
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
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  const _OnboardingSlider(),

                  const SizedBox(height: 20),

                  // 로그인이 필요한 이유 안내 문구
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.primary, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '분석 기능을 사용하려면 로그인이 필요합니다.',
                            style: TextStyle(
                                color: AppTheme.primary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                        _handleLogin(context, () => auth.signInWithGoogle(), 'google'),
                  ),
                  const SizedBox(height: 12),
                  _KakaoSignInButton(
                    isLoading: auth.isKakaoLoading,
                    onPressed: () =>
                        _handleLogin(context, () => auth.signInWithKakao(), 'kakao'),
                  ),

                  const SizedBox(height: 16),

                  // 하단 텍스트 버튼으로도 홈 복귀 가능
                  TextButton(
                    onPressed: () {
                      if (widget.popAll) {
                        // 업로드 화면 + 로그인 화면 모두 닫고 홈으로
                        Navigator.popUntil(context, (route) => route.isFirst);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      '로그인 없이 둘러보기',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 13),
                    ),
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
    imagePath: 'assets/images/onboarding_1.gif',
    icon: Icons.upload_rounded,
    iconColor: Color(0xFF4FC3F7),
    tag: '1단계',
    title: '대화 사진 업로드',
    desc: '카카오톡·당근·문자 등 의심되는 대화를\n캡처해서 최대 5장 업로드하세요.',
    ),
    (
    imagePath: 'assets/images/onboarding_2.gif',
    icon: Icons.psychology_outlined,
    iconColor: Color(0xFFFFB74D),
    tag: '2단계',
    title: '심리 조작 기법 탐지',
    desc: '긴급함 유도·감정 자극·신뢰 선점 등\n사기범의 심리 전술을 정밀 분석합니다.',
    ),
    (
    imagePath: 'assets/images/onboarding_3.gif',
    icon: Icons.tips_and_updates_outlined,
    iconColor: Color(0xFF81C784),
    tag: '3단계',
    title: '결과 및 행동 지침 제공',
    desc: 'AI 사기 패턴 분석 결과와\n맞춤 행동 지침을 알려드립니다.',
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
                color: _currentIndex == i ? AppTheme.primary : AppTheme.dividerLight,
              ),
            );
          }),
        ),
      ],
    );
  }
}

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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppTheme.overlayLight,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.overlayMedium,
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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    color: AppTheme.textSecondary,
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
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Image.asset(
              'assets/icons/google_logo.png',
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Google로 계속하기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

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
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Image.asset(
              'assets/icons/kakao_logo.png',
              width: 20,
              height: 20,
            ),
          ),
          SizedBox(width: 6),
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