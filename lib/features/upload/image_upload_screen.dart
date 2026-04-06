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
import 'package:miritalk_app/core/ads/banner_ad_widget.dart';
import 'package:miritalk_app/features/consent/consent_dialog.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/analysis/analytics_service.dart';
import 'package:miritalk_app/features/analysis/screen_time_tracker.dart';

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
    AnalyticsService.instance.logScreen('image_upload'); //화면 진입 횟수
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
      if (!auth.isLoggedIn) {
        guestImageBytes = [];
        for (final asset in _selectedImages) {
          final bytes = await asset.thumbnailDataWithSize(
            const ThumbnailSize(800, 800), // 적당한 해상도
          );
          if (bytes != null) guestImageBytes.add(bytes);
        }
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalyzingScreen(
            images: files,
            isGuest: !auth.isLoggedIn,
            guestImageBytes: guestImageBytes,
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
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
        if (mb > 5) {
          _showSnackBar('${i + 1}번째 사진이 5MB를 초과합니다. (${mb.toStringAsFixed(1)}MB)');
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(title: '사진 업로드'),
      // bottomNavigationBar: const BannerAdWidget(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 설명 텍스트 ──
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 24, 12, 20),
            child: Text(
              '의심되는 대화 내역을 캡처해서 업로드하면,\n실제 사기 사례로 학습된 AI가 분석합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
            ),
          ),

          // ── 이미지 선택 영역 ──
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SizedBox(
              height: 90,
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
                        height: 90,
                        child: ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          buildDefaultDragHandles: false,
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (_, __) {
                                final scale =
                                Tween<double>(begin: 1.0, end: 1.15).evaluate(
                                  CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut),
                                );
                                return Transform.scale(
                                  scale: scale,
                                  child: Material(
                                      color: Colors.transparent, child: child),
                                );
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
          ),

          // ── 안내 문구 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _InfoRow(
                  icon: Icons.chat_outlined,
                  text: '카카오톡, 문자, 거래 앱 등 모든 대화 캡처를 분석할 수 있습니다.',
                ),
                SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.star_outline,
                  text: '첫 번째 사진을 가장 중요하거나 강조하고 싶은 장면으로 선택하세요.',
                ),
                SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.swap_vert,
                  text: '사진을 길게 눌러 드래그하면 순서를 변경할 수 있습니다.',
                ),
                SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.lock_outline,
                  text: '업로드된 사진은 분석에만 사용되며 AI 학습에 활용되지 않습니다.',
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── 분석 요청 버튼 ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor:
                  AppTheme.primary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text(
                  '분석 요청하기',
                  style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ── 카메라 버튼 위젯 ──────────────────────────────
class _CameraButton extends StatelessWidget {
  final int count;
  final int maxCount;
  final VoidCallback onTap;

  const _CameraButton(
      {required this.count, required this.maxCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 90,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: AppTheme.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              count == 0 ? '사진 선택' : '$count/$maxCount',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(snapshot.data!,
                      width: 76, height: 90, fit: BoxFit.cover),
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
                  color: Colors.black.withValues(alpha: 0.55),
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

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppTheme.primary, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }
}