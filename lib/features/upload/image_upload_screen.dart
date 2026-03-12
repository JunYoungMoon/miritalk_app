import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'gallery_picker_screen.dart';

class ImageUploadScreen extends StatefulWidget {
  final bool showAppBar;
  const ImageUploadScreen({super.key, this.showAppBar = true});

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  final List<AssetEntity> _selectedImages = [];
  static const int _maxImages = 5;
  bool _isUploading = false;

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
    if (_selectedImages.length < _maxImages) {
      _showSnackBar('사진 $_maxImages장을 모두 선택해주세요.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/fraud/analyze'),
      );

      for (final asset in _selectedImages) {
        final file = await asset.file;
        if (file != null) {
          request.files.add(
            await http.MultipartFile.fromPath('images', file.path),
          );
        }
      }

      final response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnackBar('업로드 완료! 분석 중입니다.');
      } else {
        _showSnackBar('업로드 실패. 다시 시도해주세요.');
      }
    } catch (e) {
      if (mounted) _showSnackBar('오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: widget.showAppBar
          ? AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('사진 업로드',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 이미지 선택 영역 ──
          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              height: 90,
              child: Row(
                children: [
                  // 카메라 버튼 (항상 고정 좌측)
                  _CameraButton(
                    count: _selectedImages.length,
                    maxCount: _maxImages,
                    onTap: _openGallery,
                  ),

                  // 선택된 이미지 목록 (드래그 순서 변경 가능)
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (_, __) => Transform.scale(
                              scale: 1.08,
                              child: child,
                            ),
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
                          return ReorderableDragStartListener(
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
                  ],
                ],
              ),
            ),
          ),

          // ── 안내 문구 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사기 피해 분석',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  '사기 관련 사진 5장을 업로드하면 AI가 분석합니다.',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF4FC3F7), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '첫 번째 사진이 대표 이미지로 사용됩니다.',
                      style: const TextStyle(
                          color: Color(0xFF4FC3F7), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF4FC3F7), size: 14),
                    const SizedBox(width: 4),
                    Expanded(  // 추가
                      child: Text(
                        '사진을 길게 눌러 드래그하면 순서를 변경할 수 있습니다.',
                        style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 진행 상태 표시 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: _ProgressIndicatorRow(
              current: _selectedImages.length,
              total: _maxImages,
            ),
          ),

          const Spacer(),

          // ── 분석 요청 버튼 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: ElevatedButton(
              onPressed: _isUploading ? null : _uploadImages,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                disabledBackgroundColor:
                const Color(0xFF4FC3F7).withOpacity(0.3),
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
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

  const _CameraButton({
    required this.count,
    required this.maxCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF4FC3F7).withOpacity(0.4),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Color(0xFF4FC3F7), size: 28),
            const SizedBox(height: 6),
            Text(
              '$count/$maxCount',
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontSize: 12,
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

  const _ImageThumbnail({
    required this.asset,
    required this.isFirst,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 90,
      child: Stack(
        children: [
          // 썸네일 이미지
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
              const ThumbnailSize.square(150),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.data != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    snapshot.data!,
                    width: 76,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 76,
                  height: 90,
                  color: const Color(0xFF0F3460),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF4FC3F7),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 대표 이미지 뱃지 (첫 번째 이미지)
          if (isFirst)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
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
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // X 버튼
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 진행 상태 바 위젯 ─────────────────────────────
class _ProgressIndicatorRow extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicatorRow({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '사진 선택',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            Text(
              '$current / $total',
              style: TextStyle(
                color: current == total
                    ? const Color(0xFF4FC3F7)
                    : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: current / total,
            backgroundColor: const Color(0xFF0F3460),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}