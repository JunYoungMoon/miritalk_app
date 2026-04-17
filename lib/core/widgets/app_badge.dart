// lib/core/widgets/app_badge.dart
import 'package:flutter/material.dart';

class AppBadge extends StatelessWidget {
  final String text;
  final Color color;

  /// 패딩을 직접 지정하고 싶을 때 사용. 기본값: horizontal 8, vertical 3
  final EdgeInsetsGeometry? padding;

  /// 폰트 크기. 기본값: 10
  final double fontSize;

  const AppBadge({
    super.key,
    required this.text,
    required this.color,
    this.padding,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}