// lib/core/widgets/network_image_strip.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class NetworkImageStrip extends StatelessWidget {
  final List<String> imageUrls;

  /// 썸네일 한 장의 너비·높이 (정사각형). 기본값: 72
  final double size;

  /// 최대 표시 장수. null 이면 전체 표시
  final int? maxCount;

  /// 아이템 사이 여백. 기본값: 6
  final double itemSpacing;

  const NetworkImageStrip({
    super.key,
    required this.imageUrls,
    this.size = 72,
    this.maxCount,
    this.itemSpacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    final count = maxCount != null
        ? imageUrls.length.clamp(0, maxCount!)
        : imageUrls.length;

    return SizedBox(
      height: size,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        itemBuilder: (context, i) => Container(
          width: size,
          height: size,
          margin: EdgeInsets.only(right: itemSpacing),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDeep,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrls[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_outlined,
                color: AppTheme.textHint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}