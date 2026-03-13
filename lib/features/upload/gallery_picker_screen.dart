// lib/features/upload/gallery_picker_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class GalleryPickerScreen extends StatefulWidget {
  final int maxImages;
  final List<AssetEntity> initialSelected;

  const GalleryPickerScreen({
    super.key,
    required this.maxImages,
    this.initialSelected = const [],
  });

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  bool _loading = true;
  bool _permissionDenied = false;
  bool _isPopping = false;

  // 드래그 선택 상태
  int? _dragStartIndex;
  int? _dragCurrentIndex;
  bool _isDragSelecting = false;
  bool _dragSelectMode = true; // true = 추가 선택, false = 선택 해제

  final ScrollController _scrollController = ScrollController();
  static const int _crossAxisCount = 3;
  double _itemSize = 0;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
    _loadAssets();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    if (!ps.isAuth && !ps.hasAccess) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final allPhotos = albums.firstWhere(
          (a) => a.isAll,
      orElse: () => albums.first,
    );

    final assets = await allPhotos.getAssetListRange(start: 0, end: 300);
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  /// 화면 좌표 → 그리드 인덱스 변환 (스크롤 오프셋 반영)
  int _indexFromOffset(Offset localOffset) {
    if (_itemSize == 0) return -1;
    final scrollOffset =
    _scrollController.hasClients ? _scrollController.offset : 0.0;
    final adjustedY = localOffset.dy + scrollOffset;
    final col =
    (localOffset.dx / _itemSize).floor().clamp(0, _crossAxisCount - 1);
    final row = (adjustedY / _itemSize).floor();
    final index = row * _crossAxisCount + col;
    return index.clamp(0, _assets.length - 1);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final index = _indexFromOffset(details.localPosition);
    if (index < 0 || index >= _assets.length) return;
    final asset = _assets[index];

    setState(() {
      _isDragSelecting = true;
      _dragStartIndex = index;
      _dragCurrentIndex = index;
      // 이미 선택된 경우 드래그로 해제, 아닌 경우 드래그로 추가
      _dragSelectMode = !_selected.contains(asset);

      if (_dragSelectMode) {
        if (!_selected.contains(asset) &&
            _selected.length < widget.maxImages) {
          _selected.add(asset);
        }
      } else {
        _selected.remove(asset);
      }
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragSelecting || _dragStartIndex == null) return;
    final index = _indexFromOffset(details.localPosition);
    if (index < 0 || index >= _assets.length || index == _dragCurrentIndex) {
      return;
    }

    final start = _dragStartIndex!;
    final end = index;
    final min = start < end ? start : end;
    final max = start < end ? end : start;

    setState(() {
      _dragCurrentIndex = index;
      for (int i = min; i <= max; i++) {
        if (i >= _assets.length) break;
        final asset = _assets[i];
        if (_dragSelectMode) {
          if (!_selected.contains(asset) &&
              _selected.length < widget.maxImages) {
            _selected.add(asset);
          }
        } else {
          _selected.remove(asset);
        }
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isDragSelecting = false;
      _dragStartIndex = null;
      _dragCurrentIndex = null;
    });
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else if (_selected.length < widget.maxImages) {
        _selected.add(asset);
      }
    });
  }

  bool _isInDragRange(int index) {
    if (!_isDragSelecting ||
        _dragStartIndex == null ||
        _dragCurrentIndex == null) return false;
    final min = _dragStartIndex! < _dragCurrentIndex!
        ? _dragStartIndex!
        : _dragCurrentIndex!;
    final max = _dragStartIndex! > _dragCurrentIndex!
        ? _dragStartIndex!
        : _dragCurrentIndex!;
    return index >= min && index <= max;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_selected.length}/${widget.maxImages}',
          style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_isPopping) return;
              _isPopping = true;
              Navigator.pop(context, List<AssetEntity>.from(_selected));
            },
            child: Text(
              '완료',
              style: TextStyle(
                color: _selected.isNotEmpty
                    ? AppTheme.primary
                    : AppTheme.textHint,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined,
                color: AppTheme.textHint, size: 52),
            const SizedBox(height: 16),
            const Text('사진 접근 권한이 필요합니다',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => PhotoManager.openSetting(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
              ),
              child: const Text('설정 열기'),
            ),
          ],
        ),
      );
    }

    if (_assets.isEmpty) {
      return const Center(
        child:
        Text('사진이 없습니다', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: [
        // 드래그 안내 배너
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _isDragSelecting ? 36 : 0,
          color: AppTheme.primary.withValues(alpha:0.15),
          child: const Center(
            child: Text(
              '드래그하여 여러 장 선택',
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _itemSize = constraints.maxWidth / _crossAxisCount;
              return GestureDetector(
                onLongPressStart: _onLongPressStart,
                onLongPressMoveUpdate: _onLongPressMoveUpdate,
                onLongPressEnd: _onLongPressEnd,
                child: GridView.builder(
                  controller: _scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _crossAxisCount,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (context, index) {
                    final asset = _assets[index];
                    final isSelected = _selected.contains(asset);
                    final selectionNumber =
                    isSelected ? _selected.indexOf(asset) + 1 : null;
                    final inDragRange = _isInDragRange(index);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque, // 추가
                      onTap: () {
                        if (_isPopping) return; // 추가
                        _toggleSelection(asset);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 썸네일
                          FutureBuilder<Uint8List?>(
                            future: asset.thumbnailDataWithSize(
                              const ThumbnailSize.square(200),
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done &&
                                  snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                );
                              }
                              return Container(
                                  color: AppTheme.background);
                            },
                          ),

                          // 선택/드래그 오버레이
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 100),
                            opacity: (isSelected || inDragRange) ? 1.0 : 0.0,
                            child: Container(
                              color: Colors.black.withValues(alpha:0.35),
                            ),
                          ),

                          // 선택 번호 뱃지
                          Positioned(
                            top: 5,
                            right: 5,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary,
                                  width: 1.8,
                                ),
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha:0.4),
                                    blurRadius: 4,
                                  )
                                ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Center(
                                child: Text(
                                  '$selectionNumber',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}