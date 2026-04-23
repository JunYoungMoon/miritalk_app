// lib/features/inquiry/inquiry_list_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// 모델
// ══════════════════════════════════════════════════════════════
class InquiryItem {
  final int id;
  final String content;
  final String? email;
  final String? replyContent;
  final String status;       // RECEIVED | ANSWERED
  final String createdAt;
  final String? repliedAt;

  const InquiryItem({
    required this.id,
    required this.content,
    this.email,
    this.replyContent,
    required this.status,
    required this.createdAt,
    this.repliedAt,
  });

  factory InquiryItem.fromJson(Map<String, dynamic> json) => InquiryItem(
    id: json['id'] as int,
    content: json['content'] as String? ?? '',
    email: json['email'] as String?,
    replyContent: json['replyContent'] as String?,
    status: json['status'] as String? ?? 'RECEIVED',
    createdAt: json['createdAt'] as String? ?? '',
    repliedAt: json['repliedAt'] as String?,
  );

  bool get isAnswered => status == 'ANSWERED';
}

// ISO 날짜 → 표시용 변환
String _formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    final dt = DateTime.parse(dateStr.replaceFirst(' ', 'T')).toLocal();
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return dateStr;
  }
}

// ══════════════════════════════════════════════════════════════
// InquiryListScreen
// ══════════════════════════════════════════════════════════════
class InquiryListScreen extends StatefulWidget {
  const InquiryListScreen({super.key});

  @override
  State<InquiryListScreen> createState() => _InquiryListScreenState();
}

class _InquiryListScreenState extends State<InquiryListScreen> {
  List<InquiryItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final resp = await ApiClient().get(
        '/api/inquiry',
        includeDeviceId: true,
      );
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
        setState(() {
          _items = list
              .map((e) => InquiryItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '문의 내역을 불러오지 못했습니다.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '네트워크 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '문의 내역',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,
                color: AppTheme.textSecondary, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.textHint, size: 40),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: const Text('다시 시도',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.inbox_outlined,
                  color: AppTheme.textHint, size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              '문의 내역이 없습니다',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              '불편한 점이 있으시면 언제든지 문의해주세요.',
              style: TextStyle(color: AppTheme.textHint, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _items.length,
        itemBuilder: (_, i) => _InquiryTile(
          item: _items[i],
          isFirst: i == 0,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 문의 타일
// ══════════════════════════════════════════════════════════════
class _InquiryTile extends StatefulWidget {
  final InquiryItem item;
  final bool isFirst;

  const _InquiryTile({required this.item, this.isFirst = false});

  @override
  State<_InquiryTile> createState() => _InquiryTileState();
}

class _InquiryTileState extends State<_InquiryTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    // 최신 문의이면서 답변 완료인 경우 기본 펼침
    _expanded = widget.isFirst && widget.item.isAnswered;

    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isAnswered
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.divider,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // ── 문의 헤더 (항상 표시) ──────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 뱃지 + 날짜 + 펼침 아이콘
                  Row(
                    children: [
                      _StatusBadge(isAnswered: item.isAnswered),
                      const SizedBox(width: 8),
                      Text(
                        '#${item.id}',
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 10),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(item.createdAt),
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 10),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: AppTheme.textHint, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 문의 내용
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDeep,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Center(
                          child: Text(
                            'Q',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.content,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 답변 영역 (펼쳐질 때만 표시) ─────────────────
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: item.isAnswered
                ? _AnswerSection(item: item)
                : const _PendingSection(),
          ),
        ],
      ),
    );
  }
}

// ── 답변 완료 섹션 ─────────────────────────────────────────────
class _AnswerSection extends StatelessWidget {
  final InquiryItem item;
  const _AnswerSection({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.15),
            width: 0.8,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '미리톡 답변',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (item.repliedAt != null)
                Text(
                  _formatDate(item.repliedAt),
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              item.replyContent ?? '',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 답변 대기 섹션 ─────────────────────────────────────────────
class _PendingSection extends StatelessWidget {
  const _PendingSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDeep,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppTheme.textHint,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '검토 후 빠르게 답변 드리겠습니다.',
            style: TextStyle(color: AppTheme.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── 상태 뱃지 ──────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isAnswered;
  const _StatusBadge({required this.isAnswered});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAnswered
            ? AppTheme.primary.withValues(alpha: 0.12)
            : AppTheme.surfaceDeep,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAnswered
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.divider,
          width: 0.5,
        ),
      ),
      child: Text(
        isAnswered ? '답변완료' : '답변대기',
        style: TextStyle(
          color: isAnswered ? AppTheme.primary : AppTheme.textHint,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}