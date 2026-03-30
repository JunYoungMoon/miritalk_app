// lib/features/home/widgets/scroll_hint_arrow.dart
import 'package:flutter/material.dart';

class ScrollHintArrow extends StatefulWidget {
  final VoidCallback onTap;
  const ScrollHintArrow({super.key, required this.onTap});

  @override
  State<ScrollHintArrow> createState() => _ScrollHintArrowState();
}

class _ScrollHintArrowState extends State<ScrollHintArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _bounce.value),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7B8FF7).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFF7B8FF7).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(height: 12),
                Text(
                  '분석하기',
                  style: TextStyle(
                    color: Color(0xFF7B8FF7),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF7B8FF7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}