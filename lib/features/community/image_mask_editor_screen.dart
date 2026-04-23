// lib/features/community/image_mask_editor_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class MaskRect {
  final Rect rect;
  final MaskType type;

  const MaskRect({required this.rect, required this.type});

  MaskRect copyWith({Rect? rect, MaskType? type}) =>
      MaskRect(rect: rect ?? this.rect, type: type ?? this.type);
}

enum MaskType { black, blur }

class ImageMaskEditorScreen extends StatefulWidget {
  final List<Uint8List> imageBytesList;
  const ImageMaskEditorScreen({super.key, required this.imageBytesList});

  @override
  State<ImageMaskEditorScreen> createState() => _ImageMaskEditorScreenState();
}

class _ImageMaskEditorScreenState extends State<ImageMaskEditorScreen> {
  int _currentIndex = 0;
  int _slideDirection = 1; // 1 = 오른쪽→왼쪽, -1 = 왼쪽→오른쪽
  MaskType _selectedType = MaskType.black;

  late List<List<MaskRect>> _masksPerImage;
  Offset? _dragStart;
  Offset? _dragCurrent;
  late List<GlobalKey> _repaintKeys;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _masksPerImage = List.generate(widget.imageBytesList.length, (_) => []);
    _repaintKeys = List.generate(widget.imageBytesList.length, (_) => GlobalKey());
  }

  void _goToIndex(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.imageBytesList.length) return;
    setState(() {
      _slideDirection = newIndex > _currentIndex ? 1 : -1;
      _currentIndex = newIndex;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  void _onPanStart(DragStartDetails d) =>
      setState(() => _dragStart = d.localPosition);

  void _onPanUpdate(DragUpdateDetails d) =>
      setState(() => _dragCurrent = d.localPosition);

  void _onPanEnd(DragEndDetails d) {
    if (_dragStart == null || _dragCurrent == null) return;
    final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
    if (rect.width > 8 && rect.height > 8) {
      setState(() => _masksPerImage[_currentIndex]
          .add(MaskRect(rect: rect, type: _selectedType)));
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

  void _clearAll() => setState(() => _masksPerImage[_currentIndex] = []);

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
    final results = <int, Uint8List>{};

    for (int i = 0; i < widget.imageBytesList.length; i++) {
      if (_masksPerImage[i].isEmpty) continue;

      final captured = await _captureImage(i);
      if (captured != null) results[i] = captured;
    }

    if (!mounted) return;
    setState(() => _isCapturing = false);
    Navigator.pop(context, results);
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.imageBytesList.length > 1;

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
                width: 18, height: 18,
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
          Expanded(
            child: Stack(
              children: [
                // ── Push 전환: 나가는 것도 슬라이드, 들어오는 것도 슬라이드 ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final isIncoming = child.key == ValueKey(_currentIndex);
                    return SlideTransition(
                      position: isIncoming
                      // 새 사진: 오른쪽(or 왼쪽)에서 들어옴
                          ? Tween<Offset>(
                        begin: Offset(_slideDirection.toDouble(), 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeInOut))
                      // 기존 사진: 왼쪽(or 오른쪽)으로 밀려남
                      // animation이 1→0이므로 begin/end 반전
                          : Tween<Offset>(
                        begin: Offset(-_slideDirection.toDouble(), 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeInOut)),
                      child: child,
                    );
                  },
                  // Stack에 clipBehavior 추가해 슬라이드 오버플로 차단
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentIndex),
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
                              ..._masksPerImage[_currentIndex]
                                  .map((m) => _MaskOverlay(mask: m)),
                              if (_dragStart != null && _dragCurrent != null)
                                Positioned.fromRect(
                                  rect: Rect.fromPoints(
                                      _dragStart!, _dragCurrent!),
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
                ),

                // ← 이전 화살표
                if (hasMultiple && _currentIndex > 0)
                  Positioned(
                    left: 8, top: 0, bottom: 0,
                    child: Center(
                      child: _NavArrow(
                        icon: Icons.chevron_left,
                        onTap: () => _goToIndex(_currentIndex - 1),
                      ),
                    ),
                  ),

                // → 다음 화살표
                if (hasMultiple &&
                    _currentIndex < widget.imageBytesList.length - 1)
                  Positioned(
                    right: 8, top: 0, bottom: 0,
                    child: Center(
                      child: _NavArrow(
                        icon: Icons.chevron_right,
                        onTap: () => _goToIndex(_currentIndex + 1),
                      ),
                    ),
                  ),

                // 상단 페이지 인디케이터
                if (hasMultiple)
                  Positioned(
                    top: 8, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: widget.imageBytesList.asMap().entries.map((e) {
                        final active = e.key == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: active ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: active ? AppTheme.primary : Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // ── 하단 툴바 ───────────────────────────
          Container(
            color: const Color(0xFF111111),
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: _ToolbarButton(
                    icon: Icons.rectangle,
                    label: '검정 가리기',
                    selected: _selectedType == MaskType.black,
                    onTap: () => setState(() => _selectedType = MaskType.black),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToolbarButton(
                    icon: Icons.blur_on,
                    label: '모자이크',
                    selected: _selectedType == MaskType.blur,
                    onTap: () => setState(() => _selectedType = MaskType.blur),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToolbarButton(
                    icon: Icons.undo,
                    label: '되돌리기',
                    onTap: _undoLast,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToolbarButton(
                    icon: Icons.delete_outline,
                    label: '전체삭제',
                    onTap: _clearAll,
                    danger: true,
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

// ── 통합 툴바 버튼 ───────────────────────────────────
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool danger;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (danger)        color = AppTheme.danger;
    else if (selected) color = AppTheme.primary;
    else               color = Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : danger
              ? AppTheme.danger.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : danger
                ? AppTheme.danger.withValues(alpha: 0.35)
                : Colors.white24,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ── 마스크 오버레이 ──────────────────────────────────
class _MaskOverlay extends StatelessWidget {
  final MaskRect mask;
  const _MaskOverlay({required this.mask});

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (mask.type) {
      MaskType.black => Container(color: Colors.black),
      MaskType.blur  => ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
    };
    return Positioned.fromRect(rect: mask.rect, child: child);
  }
}

// ── 좌우 화살표 버튼 ─────────────────────────────────
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }
}