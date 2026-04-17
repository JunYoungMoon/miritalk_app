// lib/features/home/widgets/scroll_hint_arrow.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                SizedBox(width: 7),
                Text(
                  '분석하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}