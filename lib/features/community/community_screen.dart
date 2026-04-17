// lib/features/community/community_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'package:miritalk_app/features/community/community_detail_screen.dart';
import 'package:miritalk_app/core/widgets/app_badge.dart';
import 'package:miritalk_app/core/widgets/network_image_strip.dart';

class CommunityPost {
  final int id;
  final String category;
  final String riskLevel;
  final int riskScore;
  final String summary;
  final String verdict;
  final List<String> imageUrls;
  final String author;
  final bool anonymous;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.category,
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    required this.verdict,
    required this.imageUrls,
    required this.author,
    required this.anonymous,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
    id: j['id'] as int,
    category: j['category'] as String? ?? '기타',
    riskLevel: j['riskLevel'] as String? ?? '',
    riskScore: j['riskScore'] as int? ?? 0,
    summary: j['summary'] as String? ?? '',
    verdict: j['verdict'] as String? ?? '',
    imageUrls: (j['imageUrls'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        [],
    author: j['author'] as String? ?? '익명',
    anonymous: j['anonymous'] as bool? ?? true,
    likeCount: j['likeCount'] as int? ?? 0,
    commentCount: j['commentCount'] as int? ?? 0,
    likedByMe: j['likedByMe'] as bool? ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final List<CommunityPost> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  String _selectedCategory = '전체';

  static const _categories = ['전체', '직거래', '로맨스', '투자', '취업', '피싱', '기타'];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading || (!_hasMore && !reset)) return;
    if (reset) {
      setState(() {
        _posts.clear();
        _page = 0;
        _hasMore = true;
      });
    }
    setState(() => _isLoading = true);
    try {
      final cat = _selectedCategory == '전체' ? '' : '&category=$_selectedCategory';
      final response = await ApiClient()
          .get('/api/community/posts?page=$_page&size=10$cat');
      final json =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (json['content'] as List<dynamic>)
          .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _posts.addAll(items);
        _page++;
        _hasMore = !(json['last'] as bool? ?? true);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final liked = !post.likedByMe;
    setState(() {
      _posts[index] = CommunityPost(
        id: post.id,
        category: post.category,
        riskLevel: post.riskLevel,
        riskScore: post.riskScore,
        summary: post.summary,
        verdict: post.verdict,
        imageUrls: post.imageUrls,
        author: post.author,
        anonymous: post.anonymous,
        likeCount: post.likeCount + (liked ? 1 : -1),
        commentCount: post.commentCount,
        likedByMe: liked,
        createdAt: post.createdAt,
      );
    });
    try {
      await ApiClient().post('/api/community/posts/${post.id}/like',
          body: {'liked': liked});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(title: '사기 제보 커뮤니티'),
      body: Column(
        children: [
          // ── 카테고리 탭 ──────────────────────────
          _CategoryTabBar(
            categories: _categories,
            selected: _selectedCategory,
            onSelect: (c) {
              setState(() => _selectedCategory = c);
              _load(reset: true);
            },
          ),

          // ── 피드 목록 ────────────────────────────
          Expanded(
            child: _posts.isEmpty && !_isLoading
                ? _EmptyState(category: _selectedCategory)
                : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _posts.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2),
                    ),
                  );
                }
                return _PostCard(
                  post: _posts[index],
                  onLike: () => _toggleLike(index),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityDetailScreen(
                        postId: _posts[index].id,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 카테고리 탭바 ────────────────────────────────────
class _CategoryTabBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryTabBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AppTheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final sel = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.surfaceDeep,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? AppTheme.primary : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    color: sel ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight:
                    sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 피드 카드 ────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onTap,
  });

  Color get _riskColor => AppTheme.riskLevelColor(post.riskLevel);

  String _timeAgo() {
    final diff = DateTime.now().difference(post.createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${post.createdAt.month}/${post.createdAt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _riskColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 카테고리 뱃지 + 위험도 + 시간
            Row(
              children: [
                AppBadge(text: post.category, color: AppTheme.primary),
                const SizedBox(width: 6),
                AppBadge(
                  text: '${post.riskLevel} ${post.riskScore}%',
                  color: _riskColor,
                ),
                const Spacer(),
                Text(_timeAgo(),
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),

            // 요약 텍스트
            Text(
              post.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  height: 1.5),
            ),

            // 이미지 썸네일 (있을 때만)
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              NetworkImageStrip(
                imageUrls: post.imageUrls,
                size: 56,
                maxCount: 4,
              ),
            ],
            const SizedBox(height: 10),

            // 푸터: 작성자 + 좋아요 + 댓글
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: AppTheme.textHint, size: 13),
                const SizedBox(width: 3),
                Text(
                  post.anonymous ? '익명' : post.author,
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onLike,
                  child: Row(
                    children: [
                      Icon(
                        post.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.likedByMe
                            ? AppTheme.danger
                            : AppTheme.textHint,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text('${post.likeCount}',
                          style: TextStyle(
                              color: post.likedByMe
                                  ? AppTheme.danger
                                  : AppTheme.textHint,
                              fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: AppTheme.textHint, size: 14),
                    const SizedBox(width: 3),
                    Text('${post.commentCount}',
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 뱃지 → lib/core/widgets/app_badge.dart 의 AppBadge 사용
// (이 파일에서 _Badge 클래스 제거됨)

// ── 빈 상태 ──────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String category;
  const _EmptyState({required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined,
              color: AppTheme.textHint, size: 48),
          const SizedBox(height: 12),
          Text(
            category == '전체'
                ? '아직 공유된 제보가 없어요'
                : '$category 유형의 제보가 없어요',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            '분석 결과 화면에서 공유하기를 눌러보세요',
            style:
            TextStyle(color: AppTheme.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}