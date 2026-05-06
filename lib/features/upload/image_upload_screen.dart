// lib/features/upload/image_upload_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:http/http.dart' as http;
import 'gallery_picker_screen.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'package:miritalk_app/features/analysis/analyzing_screen.dart';
import 'package:miritalk_app/features/analysis/analysis_error.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'package:miritalk_app/core/ads/ad_manager.dart';
import 'package:miritalk_app/core/ads/banner_ad_widget.dart';
import 'package:miritalk_app/features/consent/consent_dialog.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/core/tracking/tracking_service.dart';
import 'package:miritalk_app/core/tracking/screen_time_tracker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ImageUploadScreen extends StatefulWidget {
  const ImageUploadScreen({super.key});

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  final List<AssetEntity> _selectedImages = [];
  static const int _maxImages = 5;
  bool _isUploading = false;
  late final ScreenTimeTracker _tracker;

  @override
  void initState() {
    super.initState();
    _tracker = ScreenTimeTracker('image_upload'); //체류시간 측정
    TrackingService.instance.logScreen('image_upload'); //화면 진입 횟수
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _openGallery() async {
    final result = await Navigator.push<List<AssetEntity>>(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPickerScreen(
          maxImages: _maxImages,
          initialSelected: List.from(_selectedImages),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedImages
          ..clear()
          ..addAll(result);
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) {
      _showSnackBar('사진을 먼저 선택해주세요.');
      return;
    }

    // ── 동의 확인 ──
    final consented = await ConsentDialog.ensureConsent(context);
    if (!consented) return;

    final isValid = await _validateImages();
    if (!isValid) return;

    setState(() => _isUploading = true);
    try {
      final files = <http.MultipartFile>[];
      for (final asset in _selectedImages) {
        final file = await asset.file;
        if (file != null) {
          files.add(await http.MultipartFile.fromPath('images', file.path));
        }
      }

      setState(() => _isUploading = false);

      final auth = context.read<AuthProvider>();

      // 게스트일 때 미리 바이트 수집
      List<Uint8List>? guestImageBytes;
      String? guestFcmToken;
      if (!auth.isLoggedIn) {
        guestImageBytes = [];
        for (final asset in _selectedImages) {
          final file = await asset.file;
          if (file != null) {
            final bytes = await file.readAsBytes();
            guestImageBytes.add(bytes);
          }
        }

        // 게스트 FCM 토큰 가져오기
        try {
          guestFcmToken = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          debugPrint('게스트 FCM 토큰 가져오기 실패: $e');
        }
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalyzingScreen(
            images: files,
            isGuest: !auth.isLoggedIn,
            guestImageBytes: guestImageBytes,
            guestFcmToken: guestFcmToken,
          ),
        ),
      );

      if (!mounted) return;

      if (result is AnalysisError) {
        switch (result.errorCode) {
          case 'QUOTA_ERROR':
            _showQuotaDialog(result.message);
            break;
          case 'AUTH_ERROR':
            _showErrorDialog(
              result.message,
              onConfirm: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            );
            break;
          default:
            _showErrorDialog(result.message);
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('오류가 발생했습니다: $e');
        setState(() => _isUploading = false);
      }
    }
  }

  void _showErrorDialog(String message, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: onConfirm == null,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
            SizedBox(width: 8),
            Text(
              '분석 실패',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm?.call();
            },
            child: const Text('확인', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showQuotaDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: AppTheme.danger, size: 20),
            SizedBox(width: 8),
            Text(
              '오늘 분석 횟수 초과',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _validateImages() async {
    for (int i = 0; i < _selectedImages.length; i++) {
      final asset = _selectedImages[i];

      final file = await asset.file;
      if (file != null) {
        final bytes = await file.length();
        final mb = bytes / (1024 * 1024);
        if (mb > 10) {
          _showSnackBar('${i + 1}번째 사진이 10MB를 초과합니다. (${mb.toStringAsFixed(1)}MB)');
          return false;
        }
      }

      if (asset.width < 100 || asset.height < 100) {
        _showSnackBar('${i + 1}번째 사진이 너무 작습니다. (${asset.width}x${asset.height})');
        return false;
      }

      final mimeType = await asset.mimeTypeAsync;
      if (mimeType != null &&
          !['image/jpeg', 'image/png', 'image/webp'].contains(mimeType)) {
        _showSnackBar('${i + 1}번째 사진은 지원하지 않는 형식입니다. (JPEG, PNG, WEBP만 가능)');
        return false;
      }
    }
    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && _selectedImages.isNotEmpty) {
            TrackingService.instance.logUploadAbandoned(_selectedImages.length);
          }
        },
        child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: const CommonAppBar(title: '사진 업로드'),
        bottomNavigationBar: const BannerAdWidget(placementKey: AdPlacements.uploadBanner),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 설명 텍스트 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: Color(0xFFBDB0FF)),
                        SizedBox(width: 6),
                        Text('실제 사기 사례로 학습된 AI',
                            style: TextStyle(color: Color(0xFFBDB0FF), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '의심되는 대화 내역을 캡처해서\n업로드해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),

            // ── 안내 문구 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: const [
                  _InfoRow(icon: Icons.chat_outlined,
                      text: '카카오톡, 문자, 거래 앱 등 모든 대화 캡처를 분석할 수 있습니다.',
                      highlight: true),
                  SizedBox(height: 8),
                  _InfoRow(icon: Icons.star_outline,
                      text: '첫 번째 사진을 가장 중요하거나 강조하고 싶은 장면으로 선택하세요.'),
                  SizedBox(height: 8),
                  _InfoRow(icon: Icons.lock_outline,
                      text: '업로드된 사진은 분석에만 사용되며 AI 학습에 활용되지 않습니다.'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 이미지 선택 영역 ──
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppTheme.divider, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(children: [
                          const TextSpan(text: '선택한 사진',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          TextSpan(text: '  ${_selectedImages.length}',
                              style: const TextStyle(color: Color(0xFFBDB0FF), fontSize: 12, fontWeight: FontWeight.w700)),
                          TextSpan(text: ' / $_maxImages',
                              style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        ]),
                      ),
                      const Row(children: [
                        Icon(Icons.reorder, color: AppTheme.textHint, size: 13),
                        SizedBox(width: 4),
                        Text('길게 눌러 순서 변경',
                            style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 92,
                    child: Row(
                      children: [
                        _CameraButton(
                          count: _selectedImages.length,
                          maxCount: _maxImages,
                          onTap: _openGallery,
                        ),
                        if (_selectedImages.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 92,
                              child: ReorderableListView.builder(
                                scrollDirection: Axis.horizontal,
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (_, __) {
                                      final scale = Tween<double>(begin: 1.0, end: 1.15)
                                          .evaluate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                                      return Transform.scale(scale: scale,
                                          child: Material(color: Colors.transparent, child: child));
                                    },
                                  );
                                },
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex--;
                                    final item = _selectedImages.removeAt(oldIndex);
                                    _selectedImages.insert(newIndex, item);
                                  });
                                },
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return ReorderableDelayedDragStartListener(
                                    key: ValueKey(_selectedImages[index].id),
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _ImageThumbnail(
                                        asset: _selectedImages[index],
                                        isFirst: index == 0,
                                        onRemove: () => _removeImage(index),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── 분석 요청 버튼 ──
            Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16,
                  MediaQuery.of(context).padding.bottom + 20),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _isUploading
                      ? LinearGradient(colors: [
                    AppTheme.primary.withValues(alpha: 0.5),
                    AppTheme.primaryDeep.withValues(alpha: 0.5),
                  ])
                      : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, AppTheme.primaryDeep],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isUploading ? null : _uploadImages,
                    child: Center(
                      child: _isUploading
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.psychology_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('분석 요청하기',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 카메라 버튼 위젯 ──────────────────────────────
class _CameraButton extends StatelessWidget {
  final int count;
  final int maxCount;
  final VoidCallback onTap;

  const _CameraButton({required this.count, required this.maxCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76, height: 92,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppTheme.primary.withValues(alpha: 0.5),
            radius: 12,
            dashWidth: 3,
            dashSpace: 2,
            strokeWidth: 1.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(height: 3),
                Text(
                  '$count/$maxCount',
                  style: const TextStyle(
                    color: Color(0xFFBDB0FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
            size.width - strokeWidth, size.height - strokeWidth),
        Radius.circular(radius),
      ));

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
          old.dashWidth != dashWidth ||
          old.dashSpace != dashSpace;
}

// ── 선택된 이미지 썸네일 위젯 ────────────────────
class _ImageThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final bool isFirst;
  final VoidCallback onRemove;

  const _ImageThumbnail(
      {required this.asset, required this.isFirst, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 90,
      child: Stack(
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
                const ThumbnailSize.square(150)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.data != null) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: isFirst
                        ? Border.all(color: AppTheme.primary, width: 1.2)
                        : Border.all(color: AppTheme.divider, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(snapshot.data!,
                        width: 76, height: 92, fit: BoxFit.cover),
                  ),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 76,
                  height: 90,
                  color: AppTheme.surface,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppTheme.primary),
                    ),
                  ),
                ),
              );
            },
          ),
          if (isFirst)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.overlayDark,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: const Text(
                  '대표',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                    color: Colors.black87, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: AppTheme.textPrimary, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 안내 아이콘 + 텍스트 위젯 ─────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _InfoRow({required this.icon, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? AppTheme.primary.withValues(alpha: 0.25)
              : AppTheme.divider,
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: highlight
                  ? AppTheme.primary.withValues(alpha: 0.18)
                  : AppTheme.surfaceDeep,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon,
                size: 13,
                color: highlight ? const Color(0xFFBDB0FF) : AppTheme.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: highlight ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 12,
                height: 1.55,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}