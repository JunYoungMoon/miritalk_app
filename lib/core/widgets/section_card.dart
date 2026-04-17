// lib/core/widgets/section_card.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget child;

  /// 카드 하단 여백. 기본값: 12
  final double bottomPadding;

  const SectionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
    this.bottomPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──
            Row(
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── 본문 ──
            child,
          ],
        ),
      ),
    );
  }
}