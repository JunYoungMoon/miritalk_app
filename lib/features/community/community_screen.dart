// lib/features/community/community_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'package:miritalk_app/features/community/community_detail_screen.dart';
import 'package:miritalk_app/core/widgets/app_badge.dart';
import 'package:miritalk_app/core/widgets/network_image_strip.dart';
import 'package:miritalk_app/core/ads/ad_manager.dart';
import 'package:miritalk_app/core/ads/banner_ad_widget.dart';

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
  final String content;
  final bool mine;

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
    required this.content,
    this.mine = false,
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
    content: j['content'] as String? ?? '',
    mine: j['mine'] as bool? ?? false,
  );

  CommunityPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    String? content,
  }) => CommunityPost(
    id: id,
    category: category,
    riskLevel: riskLevel,
    riskScore: riskScore,
    summary: summary,
    verdict: verdict,
    imageUrls: imageUrls,
    author: author,
    anonymous: anonymous,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
    createdAt: createdAt,
    content: content ?? this.content,
    mine: mine,
  );
}

class CommunityScreen extends StatefulWidget {
  final List<CommunityPost>? preloadedRanking;
  const CommunityScreen({super.key, this.preloadedRanking});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final List<CommunityPost> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  String _selectedCategory = '전체';
  List<String> _categories = ['전체'];

  // TOP3 랭킹
  List<CommunityPost> _rankingPosts = [];
  bool _rankingLoading = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.preloadedRanking != null) {
      _rankingPosts = widget.preloadedRanking!;
      _rankingLoading = false;
    } else {
      _loadRanking();
    }
    _load();
    _loadCategories();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _load();
      }
    });
  }

  // Detail 화면을 열고, 게시글이 삭제됐다면(true 반환) 리스트에서 즉시 제거한다.
  Future<void> _openDetail(int postId, CommunityPost post) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          postId: postId,
          preloadedPost: post,
        ),
      ),
    );
    if (!mounted || deleted != true) return;
    setState(() {
      _posts.removeWhere((p) => p.id == postId);
      _rankingPosts.removeWhere((p) => p.id == postId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRanking() async {
    try {
      final response = await ApiClient().get('/api/community/ranking');
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (mounted) {
        setState(() {
          _rankingPosts = list
              .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
              .toList();
          _rankingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rankingLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiClient().get('/api/fraud/categories');
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final names = list.map((e) => e['displayName'] as String).toList();
      if (mounted) setState(() => _categories = ['전체', ...names]);
    } catch (_) {}
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
      final cat =
      _selectedCategory == '전체' ? '' : '&category=$_selectedCategory';
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
      _posts[index] = post.copyWith(
        likeCount: post.likeCount + (liked ? 1 : -1),
        likedByMe: liked,
      );
    });
    try {
      await ApiClient()
          .post('/api/community/posts/${post.id}/like', body: {'liked': liked});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(title: '사기 제보 커뮤니티'),
      bottomNavigationBar: const BannerAdWidget(placementKey: AdPlacements.communityBanner),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // ── 카테고리 탭 ──
          _CategoryTabBar(
            categories: _categories,
            selected: _selectedCategory,
            onSelect: (c) {
              setState(() => _selectedCategory = c);
              _load(reset: true);
            },
          ),

          // ── 피드 목록 ──
          Expanded(
            child: _posts.isEmpty && !_isLoading
                ? _EmptyState(category: _selectedCategory)
                : ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: _posts.length + (_hasMore ? 1 : 0) + 1, // +1 for header
              itemBuilder: (context, index) {
                // ── 0번 인덱스: 랭킹 헤더 ──
                if (index == 0) {
                  return _RankingSection(
                    posts: _rankingPosts,
                    isLoading: _rankingLoading,
                    onTap: (postId) {
                      final post = _rankingPosts.firstWhere((p) => p.id == postId);
                      _openDetail(postId, post);
                    },
                  );
                }

                final postIndex = index - 1;

                // 로딩 인디케이터
                if (postIndex == _posts.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2),
                    ),
                  );
                }

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    postIndex == 0 ? 12 : 6,
                    16,
                    6,
                  ),
                  child: _PostCard(
                    post: _posts[postIndex],
                    onLike: () => _toggleLike(postIndex),
                    onTap: () => _openDetail(
                      _posts[postIndex].id,
                      _posts[postIndex],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── TOP3 랭킹 섹션 ────────────────────────────────────
class _RankingSection extends StatelessWidget {
  final List<CommunityPost> posts;
  final bool isLoading;
  final ValueChanged<int> onTap;

  const _RankingSection({
    required this.posts,
    required this.isLoading,
    required this.onTap,
  });

  static const _medalColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  static const _medalEmoji = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
        ),
      );
    }

    if (posts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 10),
            child: Row(
              children: [
                const Text('🏆',style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                const Text('많이 도움된 제보',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                const Text('좋아요순',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                const SizedBox(width: 16),
              ],
            ),
          ),

          // 가로 스크롤 카드
          SizedBox(
            height: 118,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final post = posts[i];
                final medalColor = _medalColors[i];
                final riskColor = AppTheme.riskLevelColor(post.riskLevel);

                return GestureDetector(
                  onTap: () => onTap(post.id),
                  child: Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: medalColor.withValues(alpha: 0.35),
                          width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 메달 + 좋아요
                        Row(
                          children: [
                            Text(_medalEmoji[i], style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: riskColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${post.riskLevel} ${post.riskScore}%',
                                style: TextStyle(
                                    color: riskColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.favorite, color: AppTheme.danger, size: 12),
                            const SizedBox(width: 2),
                            Text('${post.likeCount}',
                                style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6), // 8 → 6으로 축소

                        // 내용
                        Text(
                          post.content.isNotEmpty ? post.content : post.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4), // 6 → 4으로 축소

                        // 카테고리
                        Text(
                          post.category,
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
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
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
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
class _PostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onTap,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showSummary = false;

  Color get _riskColor => AppTheme.riskLevelColor(widget.post.riskLevel);

  String _timeAgo() {
    final post = widget.post;
    final diff = DateTime.now().difference(post.createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${post.createdAt.month}/${post.createdAt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasContent = post.content.trim().isNotEmpty;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _riskColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppBadge(text: post.category, color: AppTheme.primary),
                const SizedBox(width: 6),
                AppBadge(
                    text: '${post.riskLevel} ${post.riskScore}%',
                    color: _riskColor),
                const Spacer(),
                Text(_timeAgo(),
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),

            // 본문(2줄) + AI 요약 토글
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    hasContent ? post.content : post.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        height: 1.5),
                  ),
                ),
                if (hasContent) ...[
                  const SizedBox(width: 8),
                  _SummaryToggle(
                    expanded: _showSummary,
                    onTap: () =>
                        setState(() => _showSummary = !_showSummary),
                  ),
                ],
              ],
            ),

            // AI 요약 펼침
            if (hasContent && _showSummary) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.smart_toy_outlined,
                        color: AppTheme.primary, size: 13),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        post.summary,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              NetworkImageStrip(
                  imageUrls: post.imageUrls, size: 56, maxCount: 4),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: AppTheme.textHint, size: 13),
                const SizedBox(width: 3),
                Text(post.anonymous ? '익명' : post.author,
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onLike,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: expanded
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surfaceDeep,
          borderRadius: BorderRadius.circular(10),
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
              size: 12,
              color: expanded ? AppTheme.primary : AppTheme.textHint,
            ),
            const SizedBox(width: 3),
            Text(
              'AI 요약',
              style: TextStyle(
                color: expanded ? AppTheme.primary : AppTheme.textHint,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          const Icon(Icons.forum_outlined, color: AppTheme.textHint, size: 48),
          const SizedBox(height: 12),
          Text(
            category == '전체'
                ? '아직 공유된 제보가 없어요'
                : '$category 유형의 제보가 없어요',
            style:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            '분석 결과 화면에서 공유하기를 눌러보세요',
            style: TextStyle(color: AppTheme.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}