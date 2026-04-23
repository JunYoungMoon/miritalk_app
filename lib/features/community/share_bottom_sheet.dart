// lib/features/community/share_bottom_sheet.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/community/image_mask_editor_screen.dart';

class ShareBottomSheet extends StatefulWidget {
  final int sessionId;
  final String riskLevel;
  final int riskScore;
  final String summary;
  final Future<List<Uint8List>> imagesFuture;
  final Future<List<Map<String, dynamic>>>? categoriesFuture;
  final String? categoryName;

  const ShareBottomSheet({
    super.key,
    required this.sessionId,
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    required this.imagesFuture,
    this.categoriesFuture,
    this.categoryName,
  });

  static Future<ShareResult?> show(
      BuildContext context, {
        required int sessionId,
        required String riskLevel,
        required int riskScore,
        required String summary,
        required Future<List<Uint8List>> imagesFuture,
        Future<List<Map<String, dynamic>>>? categoriesFuture,
        String? categoryName,
      }) {
    return showModalBottomSheet<ShareResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ShareBottomSheet(
        sessionId: sessionId,
        riskLevel: riskLevel,
        riskScore: riskScore,
        summary: summary,
        imagesFuture: imagesFuture,
        categoriesFuture: categoriesFuture,
        categoryName: categoryName,
      ),
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  // 이미지
  List<Uint8List> _imageBytes = [];
  bool _imagesLoading = true;
  Map<int, Uint8List>? _editedImageMap;

  // 설정
  bool _includeImages = true;
  bool _anonymous = true;
  bool _isSubmitting = false;

  // 카테고리
  List<Map<String, dynamic>> _categories = [];
  bool _categoriesLoading = true;
  String? _selectedDisplayName;
  bool _autoSelected = false;
  final TextEditingController _contentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _resolveImages();
    _resolveCategories();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveImages() async {
    try {
      // 프리패치가 완료됐으면 즉시 반환, 아니면 기다림
      final bytes = await widget.imagesFuture;
      if (mounted) setState(() { _imageBytes = bytes; _imagesLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _imagesLoading = false);
    }
  }

  Future<void> _resolveCategories() async {
    try {
      List<Map<String, dynamic>> categories;

      if (widget.categoriesFuture != null) {
        // 프리패치된 Future 사용 (완료됐으면 즉시)
        categories = await widget.categoriesFuture!;
      } else {
        // fallback: 직접 호출
        final response = await ApiClient().get('/api/fraud/categories');
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        categories = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      String? selected;
      bool autoSelected = false;

      if (widget.categoryName != null) {
        final match = categories.firstWhere(
              (c) => c['displayName'] == widget.categoryName,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          selected = match['displayName'] as String;
          autoSelected = true;
        }
      }
      selected ??= categories.isNotEmpty
          ? categories.first['displayName'] as String
          : null;

      if (mounted) {
        setState(() {
          _categories = categories;
          _selectedDisplayName = selected;
          _autoSelected = autoSelected;
          _categoriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Color get _riskColor {
    switch (widget.riskLevel) {
      case '매우높음': return AppTheme.danger;
      case '높음':    return Colors.orange;
      case '보통':    return Colors.yellow;
      default:        return AppTheme.success;
    }
  }

  Future<void> _openEditor() async {
    final edited = await Navigator.push<Map<int, Uint8List>>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageMaskEditorScreen(
          imageBytesList: _imageBytes,
        ),
      ),
    );
    if (edited != null) setState(() => _editedImageMap = edited);
  }

  void _submit() {
    if (_selectedDisplayName == null) return;

    final editedImages = _includeImages
        ? (_editedImageMap?.values.toList() ?? [])
        : <Uint8List>[];
    final editedOrders = _includeImages
        ? (_editedImageMap?.keys.toList() ?? [])
        : <int>[];

    Navigator.pop(
      context,
      ShareResult(
        sessionId: widget.sessionId,
        category: _selectedDisplayName!,
        anonymous: _anonymous,
        includeImages: _includeImages,
        editedImages: editedImages,
        editedImageOrders: editedOrders,
        content: _contentCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(children: [
                const Icon(Icons.share_outlined, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                const Text('커뮤니티에 공유',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              const Text(
                '다른 사용자들이 비슷한 사기 패턴을 조심할 수 있도록 도와주세요',
                style: TextStyle(color: AppTheme.textHint, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),

              // 분석 요약
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _riskColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.riskLevel} ${widget.riskScore}%',
                        style: TextStyle(
                            color: _riskColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 사기 유형
              Row(
                children: [
                  const Text('사기 유형',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  if (_autoSelected) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('AI 자동 선택',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (_categoriesLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _categories.map((c) {
                    final displayName = c['displayName'] as String;
                    final sel = _selectedDisplayName == displayName;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedDisplayName = displayName;
                        _autoSelected = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.primary.withValues(alpha: 0.2)
                              : AppTheme.surfaceDeep,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? AppTheme.primary : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: sel ? AppTheme.primary : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),

              // 이미지 포함
              if (_imagesLoading || _imageBytes.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('이미지 포함',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          const Text(
                            '공유 전 개인정보를 반드시 가려주세요',
                            style: TextStyle(color: AppTheme.danger, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    _imagesLoading
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary))
                        : Switch(
                      value: _includeImages,
                      onChanged: (v) => setState(() => _includeImages = v),
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
                if (!_imagesLoading && _includeImages) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openEditor,
                      icon: Icon(
                        _editedImageMap != null
                            ? Icons.check_circle_outline
                            : Icons.edit_outlined,
                        size: 16,
                        color: _editedImageMap != null
                            ? AppTheme.success
                            : AppTheme.primary,
                      ),
                      label: Text(
                        _editedImageMap != null
                            ? '편집 완료 (다시 편집하기)'
                            : '개인정보 가리기 (권장)',
                        style: TextStyle(
                          color: _editedImageMap != null
                              ? AppTheme.success
                              : AppTheme.primary,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _editedImageMap != null
                              ? AppTheme.success
                              : AppTheme.primary,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],

              const Text('한 줄 설명',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _contentCtrl,
                maxLength: 100,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '어떤 상황이었는지 간단히 적어주세요 (선택)',
                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.surfaceDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  counterStyle: const TextStyle(color: AppTheme.textHint, fontSize: 10),
                ),
              ),
              const SizedBox(height: 12),

              // 익명 설정
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('익명으로 공유',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('닉네임 대신 "익명"으로 표시됩니다',
                            style: TextStyle(
                                color: AppTheme.textHint, fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                    activeColor: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting ||
                      _selectedDisplayName == null ||
                      (_includeImages && _imagesLoading))
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : (_includeImages && _imagesLoading)
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white70)),
                      SizedBox(width: 8),
                      Text('이미지 준비 중...',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 15)),
                    ],
                  )
                      : const Text('커뮤니티에 공유하기',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShareResult {
  final int sessionId;
  final String category;
  final bool anonymous;
  final bool includeImages;
  final List<Uint8List> editedImages;
  final List<int> editedImageOrders;
  final String content;

  const ShareResult({
    required this.sessionId,
    required this.category,
    required this.anonymous,
    required this.includeImages,
    required this.editedImages,
    required this.editedImageOrders,
    required this.content,
  });
}