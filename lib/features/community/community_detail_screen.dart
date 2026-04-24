// lib/features/community/community_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'package:miritalk_app/features/community/community_screen.dart';
import 'package:miritalk_app/core/widgets/app_badge.dart';
import 'package:miritalk_app/core/widgets/network_image_strip.dart';

class CommunityDetailScreen extends StatefulWidget {
  final int postId;
  final CommunityPost? preloadedPost;

  const CommunityDetailScreen({
    super.key,
    required this.postId,
    this.preloadedPost,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  CommunityPost? _post;
  final List<_Comment> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _isSending = false;
  bool _showAiSummary = false;

  @override
  void initState() {
    super.initState();
    // 미리 받은 데이터가 있으면 즉시 표시, 댓글만 API로 보완
    if (widget.preloadedPost != null) {
      _post = widget.preloadedPost;
      _isLoading = false;
      _loadCommentsOnly(); // ← 댓글만 따로 로딩
    } else {
      _loadDetail();
    }
  }
  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final r = await ApiClient()
          .get('/api/community/posts/${widget.postId}');
      final json =
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final post = CommunityPost.fromJson(json);
      final comments = (json['comments'] as List<dynamic>? ?? [])
          .map((e) => _Comment.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _post = post;
        _comments.addAll(comments);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCommentsOnly() async {
    try {
      // 댓글 전용 엔드포인트 — 상세 조회 5쿼리 대신 댓글 1쿼리만
      final r = await ApiClient()
          .get('/api/community/posts/${widget.postId}/comments');
      final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
      final comments = list
          .map((e) => _Comment.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() => _comments.addAll(comments));
      }
    } catch (_) {}
  }

  Future<void> _editPost() async {
    final post = _post;
    if (post == null) return;
    final controller = TextEditingController(text: post.content);
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('글 수정',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLength: 100,
          maxLines: 3,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: '본문을 입력하세요',
            hintStyle:
                const TextStyle(color: AppTheme.textHint, fontSize: 13),
            filled: true,
            fillColor: AppTheme.surfaceDeep,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            counterStyle:
                const TextStyle(color: AppTheme.textHint, fontSize: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogCtx, text);
            },
            child: const Text('저장',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (edited == null || edited.isEmpty || !mounted) return;

    try {
      final r = await ApiClient().put(
        '/api/community/posts/${widget.postId}',
        body: {'content': edited},
      );
      final json =
          jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _post = CommunityPost.fromJson(json));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('수정됐어요'),
        backgroundColor: AppTheme.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('수정 중 오류가 발생했어요'),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('글 삭제',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: const Text(
          '이 글을 삭제할까요? 댓글과 좋아요도 함께 삭제됩니다.',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('삭제',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ApiClient().delete('/api/community/posts/${widget.postId}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('삭제됐어요'),
        backgroundColor: AppTheme.success,
      ));
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('삭제 중 오류가 발생했어요'),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final r = await ApiClient().post(
        '/api/community/posts/${widget.postId}/comments',
        body: {'content': text},
      );
      final json =
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _comments.add(_Comment.fromJson(json));
        _commentCtrl.clear();
      });
      _commentFocus.unfocus(); // 키보드 내리기
    } catch (_) {} finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Color _riskColor(String level) => AppTheme.riskLevelColor(level);

  @override
  Widget build(BuildContext context) {
    final isMine = _post?.mine ?? false;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CommonAppBar(
        title: '제보 상세',
        extraActions: [
          if (isMine)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppTheme.textPrimary, size: 22),
              color: AppTheme.surface,
              onSelected: (v) {
                if (v == 'edit') _editPost();
                if (v == 'delete') _deletePost();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined,
                        color: AppTheme.textPrimary, size: 16),
                    SizedBox(width: 8),
                    Text('수정',
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        color: AppTheme.danger, size: 16),
                    SizedBox(width: 8),
                    Text('삭제',
                        style: TextStyle(
                            color: AppTheme.danger, fontSize: 13)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : _post == null
          ? const Center(
          child: Text('게시글을 불러올 수 없어요',
              style: TextStyle(color: AppTheme.textHint)))
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildContent(),
                if (_post!.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildImages(),
                ],
                const SizedBox(height: 20),
                _buildLikeButton(),
                const SizedBox(height: 12),
                _buildCommentSection(),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final post = _post!;
    final rc = _riskColor(post.riskLevel);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AppBadge(text: post.category, color: AppTheme.primary),
              const SizedBox(width: 6),
              AppBadge(
                  text: '${post.riskLevel} ${post.riskScore}%', color: rc),
            ]),
            const SizedBox(height: 6),
            AppBadge(text: post.verdict, color: rc),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              post.anonymous ? '익명' : post.author,
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '${post.createdAt.year}.${post.createdAt.month}.${post.createdAt.day}',
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    final post = _post!;
    final hasContent = post.content.trim().isNotEmpty;
    final mainText = hasContent ? post.content : post.summary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  mainText,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.6),
                ),
              ),
              if (hasContent) ...[
                const SizedBox(width: 8),
                _SummaryToggle(
                  expanded: _showAiSummary,
                  onTap: () =>
                      setState(() => _showAiSummary = !_showAiSummary),
                ),
              ],
            ],
          ),
          if (hasContent && _showAiSummary) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.smart_toy_outlined,
                      color: AppTheme.primary, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI 분석 요약',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.summary,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildImages() {
    return NetworkImageStrip(
      imageUrls: _post!.imageUrls,
      size: 120,
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('댓글 ${_comments.length}개',
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('첫 댓글을 남겨보세요',
                  style: TextStyle(
                      color: AppTheme.textHint, fontSize: 13)),
            ),
          )
        else
          ..._comments.map((c) => _CommentTile(comment: c)),
      ],
    );
  }

  Widget _buildCommentInput() {
    // Scaffold 의 resizeToAvoidBottomInset 이 이미 키보드만큼 올려주므로
    // 여기서는 viewInsets 를 더하면 안 됨 (이중 보정 방지).
    return Material(
      color: AppTheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  focusNode: _commentFocus,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _isSending ? null : _sendComment(),
                  onTapOutside: (_) => _commentFocus.unfocus(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요...',
                    hintStyle: const TextStyle(
                        color: AppTheme.textHint, fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.surfaceDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isSending ? null : _sendComment,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton() {
    final post = _post!;
    return GestureDetector(
      onTap: _toggleLike,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: post.likedByMe
              ? AppTheme.danger.withValues(alpha: 0.1)
              : AppTheme.surfaceDeep,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: post.likedByMe
                ? AppTheme.danger.withValues(alpha: 0.4)
                : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              post.likedByMe ? Icons.favorite : Icons.favorite_border,
              color: post.likedByMe ? AppTheme.danger : AppTheme.textHint,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '도움됐어요 ${post.likeCount}',
              style: TextStyle(
                color: post.likedByMe ? AppTheme.danger : AppTheme.textHint,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final liked = !_post!.likedByMe;
    setState(() {
      _post = _post!.copyWith(
        likeCount: _post!.likeCount + (liked ? 1 : -1),
        likedByMe: liked,
      );
    });
    try {
      await ApiClient().post(
        '/api/community/posts/${_post!.id}/like',
        body: {'liked': liked},
      );
    } catch (_) {}
  }
}

class _Comment {
  final int id;
  final String author;
  final bool anonymous;
  final String content;
  final DateTime createdAt;

  const _Comment({
    required this.id,
    required this.author,
    required this.anonymous,
    required this.content,
    required this.createdAt,
  });

  factory _Comment.fromJson(Map<String, dynamic> j) => _Comment(
    id: j['id'] as int,
    author: j['author'] as String? ?? '익명',
    anonymous: j['anonymous'] as bool? ?? true,
    content: j['content'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class _CommentTile extends StatelessWidget {
  final _Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: const Icon(Icons.person,
                color: AppTheme.primary, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    comment.anonymous ? '익명' : comment.author,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${comment.createdAt.month}/${comment.createdAt.day} '
                        '${comment.createdAt.hour.toString().padLeft(2, '0')}:'
                        '${comment.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 10),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(comment.content,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _SummaryToggle({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: expanded
              ? AppTheme.primary.withValues(alpha: 0.18)
              : AppTheme.surfaceDeep,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expanded
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.divider,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.smart_toy_outlined,
              size: 13,
              color: expanded ? AppTheme.primary : AppTheme.textHint,
            ),
            const SizedBox(width: 3),
            Text(
              'AI 요약',
              style: TextStyle(
                color: expanded ? AppTheme.primary : AppTheme.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 뱃지 → lib/core/widgets/app_badge.dart 의 AppBadge 사용
// (이 파일에서 _SmallBadge 클래스 제거됨)