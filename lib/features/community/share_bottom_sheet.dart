// lib/features/community/share_bottom_sheet.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/community/image_mask_editor_screen.dart';

/// 결과 화면에서 호출:
///   final result = await ShareBottomSheet.show(context, ...);
///   if (result != null) { 공유 API 호출 }
class ShareBottomSheet extends StatefulWidget {
  final int sessionId;
  final String riskLevel;
  final int riskScore;
  final String summary;
  final List<Uint8List> imageBytesList;
  final String? categoryName;

  const ShareBottomSheet({
    super.key,
    required this.sessionId,
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    required this.imageBytesList,
    this.categoryName,
  });

  static Future<ShareResult?> show(
      BuildContext context, {
        required int sessionId,
        required String riskLevel,
        required int riskScore,
        required String summary,
        required List<Uint8List> imageBytesList,
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
        imageBytesList: imageBytesList,
        categoryName: categoryName,
      ),
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  List<Uint8List>? _editedImages;
  bool _includeImages = true;
  bool _anonymous = true;
  String _selectedCategory = '직거래';
  bool _isSubmitting = false;

  static const _categories = ['직거래', '로맨스', '투자', '취업', '피싱', '기타'];

  // AI 분류 displayName → 커뮤니티 카테고리 매핑
  static const _categoryNameMap = {
    '중고거래 사기': '직거래',
    '투자 사기':    '투자',
    '취업 사기':    '취업',
    '보이스피싱':   '피싱',
    '로맨스 스캠':  '로맨스',
  };

  @override
  void initState() {
    super.initState();
    // 분석 결과 카테고리로 자동 선택
    if (widget.categoryName != null) {
      final mapped = _categoryNameMap[widget.categoryName!];
      if (mapped != null && _categories.contains(mapped)) {
        _selectedCategory = mapped;
      }
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
    final edited = await Navigator.push<List<Uint8List>>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageMaskEditorScreen(
          imageBytesList: _editedImages ?? widget.imageBytesList,
        ),
      ),
    );
    if (edited != null) setState(() => _editedImages = edited);
  }

  void _submit() {
    Navigator.pop(
      context,
      ShareResult(
        sessionId: widget.sessionId,
        category: _selectedCategory,
        anonymous: _anonymous,
        includeImages: _includeImages,
        editedImages: _includeImages
            ? (_editedImages ?? widget.imageBytesList)
            : [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들
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

              // 제목
              Row(children: [
                const Icon(Icons.share_outlined,
                    color: AppTheme.primary, size: 18),
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
                style: TextStyle(
                    color: AppTheme.textHint, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),

              // 분석 요약 미리보기
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _riskColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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

              // 사기 유형 선택
              Row(
                children: [
                  const Text('사기 유형',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  if (widget.categoryName != null &&
                      _categoryNameMap.containsKey(widget.categoryName)) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
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
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _categories.map((c) {
                  final sel = _selectedCategory == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.primary.withValues(alpha: 0.2)
                            : AppTheme.surfaceDeep,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? AppTheme.primary
                              : AppTheme.divider,
                        ),
                      ),
                      child: Text(c,
                          style: TextStyle(
                            color: sel
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 이미지 포함 여부 + 편집 버튼
              if (widget.imageBytesList.isNotEmpty) ...[
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
                            style: TextStyle(
                                color: AppTheme.danger, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _includeImages,
                      onChanged: (v) => setState(() => _includeImages = v),
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
                if (_includeImages) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openEditor,
                      icon: Icon(
                        _editedImages != null
                            ? Icons.check_circle_outline
                            : Icons.edit_outlined,
                        size: 16,
                        color: _editedImages != null
                            ? AppTheme.success
                            : AppTheme.primary,
                      ),
                      label: Text(
                        _editedImages != null
                            ? '편집 완료 (다시 편집하기)'
                            : '개인정보 가리기 (권장)',
                        style: TextStyle(
                          color: _editedImages != null
                              ? AppTheme.success
                              : AppTheme.primary,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _editedImages != null
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

              // 공유 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
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

/// 공유 요청 결과 모델
class ShareResult {
  final int sessionId;
  final String category;
  final bool anonymous;
  final bool includeImages;
  final List<Uint8List> editedImages;

  const ShareResult({
    required this.sessionId,
    required this.category,
    required this.anonymous,
    required this.includeImages,
    required this.editedImages,
  });
}