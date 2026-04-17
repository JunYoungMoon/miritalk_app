// lib/features/community/image_mask_editor_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

/// 마스킹 영역 하나를 표현하는 모델
class MaskRect {
  final Rect rect;
  final MaskType type;

  const MaskRect({required this.rect, required this.type});

  MaskRect copyWith({Rect? rect, MaskType? type}) =>
      MaskRect(rect: rect ?? this.rect, type: type ?? this.type);
}

enum MaskType { black, blur, emoji }

/// 결과: 편집 완료된 이미지 바이트 목록 반환
class ImageMaskEditorScreen extends StatefulWidget {
  final List<Uint8List> imageBytesList;

  const ImageMaskEditorScreen({super.key, required this.imageBytesList});

  @override
  State<ImageMaskEditorScreen> createState() => _ImageMaskEditorScreenState();
}

class _ImageMaskEditorScreenState extends State<ImageMaskEditorScreen> {
  int _currentIndex = 0;
  MaskType _selectedType = MaskType.black;

  late List<List<MaskRect>> _masksPerImage;

  Offset? _dragStart;
  Offset? _dragCurrent;

  late List<GlobalKey> _repaintKeys;
  late List<Uint8List?> _renderedBytes;

  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _masksPerImage = List.generate(widget.imageBytesList.length, (_) => []);
    _repaintKeys = List.generate(widget.imageBytesList.length, (_) => GlobalKey());
    _renderedBytes = List.generate(widget.imageBytesList.length, (_) => null);
  }

  void _onPanStart(DragStartDetails d) {
    setState(() => _dragStart = d.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _dragCurrent = d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dragStart == null || _dragCurrent == null) return;
    final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
    if (rect.width > 8 && rect.height > 8) {
      setState(() {
        _masksPerImage[_currentIndex]
            .add(MaskRect(rect: rect, type: _selectedType));
      });
    }
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  void _undoLast() {
    final masks = _masksPerImage[_currentIndex];
    if (masks.isEmpty) return;
    setState(() => masks.removeLast());
  }

  void _clearAll() {
    setState(() => _masksPerImage[_currentIndex] = []);
  }

  Future<Uint8List?> _captureImage(int index) async {
    try {
      final boundary = _repaintKeys[index].currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _done() async {
    setState(() => _isCapturing = true);
    final results = <Uint8List>[];
    for (int i = 0; i < widget.imageBytesList.length; i++) {
      final captured = await _captureImage(i);
      results.add(captured ?? widget.imageBytesList[i]);
    }
    if (!mounted) return;
    setState(() => _isCapturing = false);
    Navigator.pop(context, results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '개인정보 가리기  ${_currentIndex + 1}/${widget.imageBytesList.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: _isCapturing ? null : _done,
            child: _isCapturing
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary))
                : const Text('완료',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 안내 배너 ──────────────────────────
          Container(
            width: double.infinity,
            color: AppTheme.primary.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              '드래그해서 가리고 싶은 영역을 선택하세요 (전화번호, 계좌번호 등)',
              style: TextStyle(color: AppTheme.primary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

          // ── 이미지 편집 영역 ────────────────────
          // GestureDetector를 Stack과 같은 좌표계로 맞추기 위해
          // RepaintBoundary 안쪽으로 이동
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _repaintKeys[_currentIndex],
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    children: [
                      Image.memory(
                        widget.imageBytesList[_currentIndex],
                        fit: BoxFit.contain,
                      ),
                      // 저장된 마스크들
                      ..._masksPerImage[_currentIndex]
                          .map((m) => _MaskOverlay(mask: m)),
                      // 드래그 중인 미리보기
                      if (_dragStart != null && _dragCurrent != null)
                        Positioned.fromRect(
                          rect: Rect.fromPoints(_dragStart!, _dragCurrent!),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedType == MaskType.black
                                  ? Colors.black.withValues(alpha: 0.85)
                                  : Colors.blue.withValues(alpha: 0.4),
                              border: Border.all(
                                  color: AppTheme.primary, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 하단 툴바 ───────────────────────────
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                // 마스크 타입 선택
                Row(
                  children: MaskType.values.map((t) {
                    final selected = _selectedType == t;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = t),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.primary
                                  : Colors.white24,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                t == MaskType.black
                                    ? Icons.rectangle
                                    : t == MaskType.blur
                                    ? Icons.blur_on
                                    : Icons.tag_faces,
                                color: selected
                                    ? AppTheme.primary
                                    : Colors.white54,
                                size: 18,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                t == MaskType.black
                                    ? '검정 가리기'
                                    : t == MaskType.blur
                                    ? '모자이크'
                                    : '이모지',
                                style: TextStyle(
                                  color: selected
                                      ? AppTheme.primary
                                      : Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // ── 실행취소 / 전체삭제 / 이미지 넘기기 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      _ToolBtn(
                        icon: Icons.undo,
                        label: '되돌리기',
                        onTap: _undoLast,
                      ),
                      const SizedBox(width: 8),
                      _ToolBtn(
                        icon: Icons.delete_outline,
                        label: '전체삭제',
                        onTap: _clearAll,
                        danger: true,
                      ),
                      if (widget.imageBytesList.length > 1) ...[
                        const Spacer(),
                        Row(
                          children: widget.imageBytesList
                              .asMap()
                              .entries
                              .map((e) {
                            final active = e.key == _currentIndex;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _currentIndex = e.key;
                                _dragStart = null;
                                _dragCurrent = null;
                              }),
                              child: Container(
                                width: active ? 20 : 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppTheme.primary
                                      : Colors.white24,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
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

// ── 마스크 오버레이 위젯 ─────────────────────────────
class _MaskOverlay extends StatelessWidget {
  final MaskRect mask;
  const _MaskOverlay({required this.mask});

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (mask.type) {
      case MaskType.black:
        child = Container(color: Colors.black);
        break;
      case MaskType.blur:
        child = ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        );
        break;
      case MaskType.emoji:
        child = Container(
          color: Colors.yellow.withValues(alpha: 0.9),
          child: const Center(
            child: Text('😶', style: TextStyle(fontSize: 28)),
          ),
        );
        break;
    }

    return Positioned.fromRect(
      rect: mask.rect,
      child: child,
    );
  }
}

// ── 하단 툴 버튼 ─────────────────────────────────────
class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.danger : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}