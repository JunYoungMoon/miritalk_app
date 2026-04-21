// lib/features/community/community_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'package:miritalk_app/features/community/community_screen.dart';
import 'package:miritalk_app/core/widgets/app_badge.dart';
import 'package:miritalk_app/core/widgets/network_image_strip.dart';
import 'package:miritalk_app/core/widgets/section_card.dart';

class CommunityDetailScreen extends StatefulWidget {
  final int postId;
  const CommunityDetailScreen({super.key, required this.postId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  CommunityPost? _post;
  final List<_Comment> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
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
      setState(() {
        _comments.add(_Comment.fromJson(json));
        _commentCtrl.clear();
      });
    } catch (_) {} finally {
      setState(() => _isSending = false);
    }
  }

  Color _riskColor(String level) => AppTheme.riskLevelColor(level);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(title: '제보 상세'),
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
                _buildSummary(),
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

  Widget _buildSummary() {
    return SectionCard(
      icon: Icons.smart_toy_outlined,
      label: 'AI 분석 요약',
      color: AppTheme.primary,
      bottomPadding: 0,
      child: Text(
        _post!.summary,
        style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 13, height: 1.6),
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
    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
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
      _post = CommunityPost(
        id: _post!.id,
        category: _post!.category,
        riskLevel: _post!.riskLevel,
        riskScore: _post!.riskScore,
        summary: _post!.summary,
        verdict: _post!.verdict,
        imageUrls: _post!.imageUrls,
        author: _post!.author,
        anonymous: _post!.anonymous,
        likeCount: _post!.likeCount + (liked ? 1 : -1),
        commentCount: _post!.commentCount,
        likedByMe: liked,
        createdAt: _post!.createdAt,
        content: _post!.content,
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

// ── 뱃지 → lib/core/widgets/app_badge.dart 의 AppBadge 사용
// (이 파일에서 _SmallBadge 클래스 제거됨)