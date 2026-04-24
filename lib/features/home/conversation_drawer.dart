// lib/features/home/conversation_drawer.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/cache/app_image_cache.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/storage/guest_token_storage.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/analysis/analysis_result_screen.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'package:miritalk_app/features/community/community_screen.dart';
import 'package:miritalk_app/features/inquiry/inquiry_list_screen.dart';
import 'analysis_quota_provider.dart';
import 'conversation_provider.dart';

// ISO 날짜 → 상대 시간 변환
String _formatRelativeDate(String dateStr) {
  try {
    final dt = DateTime.parse(dateStr.replaceFirst(' ', 'T')).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return '오늘 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return '어제';
    if (diff <= 3) return '$diff일 전';
    if (diff <= 7) return '1주 전';
    if (diff <= 14) return '2주 전';
    return '${dt.month}/${dt.day}';
  } catch (_) {
    return dateStr;
  }
}

// 공통 타일 데코레이션
BoxDecoration _tileDecoration() => BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(
    color: AppTheme.primary.withValues(alpha: 0.25),
    width: 0.5,
  ),
);

// ══════════════════════════════════════════════════════════════
// ConversationDrawer
// ══════════════════════════════════════════════════════════════
class ConversationDrawer extends StatefulWidget {
  final VoidCallback onGoToUpload;
  const ConversationDrawer({super.key, required this.onGoToUpload});

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  Future<void> _onNewAnalysisTap() async {
    final auth = context.read<AuthProvider>();
    final quota = context.read<AnalysisQuotaProvider>();

    if (!auth.isLoggedIn) {
      Navigator.pop(context);
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    await quota.loadQuota(isLoggedIn: true);
    if (!mounted) return;

    if (quota.isExhausted) {
      Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('오늘 분석 횟수를 모두 사용했습니다. 내일 다시 이용해주세요.'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }

    Navigator.pop(context);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    widget.onGoToUpload();
  }

  // ── 문의 메뉴 바텀시트 ──────────────────────────────────────
  void _showInquiryMenu() {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(   // ✅ _ → sheetContext
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _InquiryMenuTile(
                  icon: Icons.inbox_outlined,
                  label: '문의 내역',
                  subtitle: '답변을 확인하세요',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      sheetContext,
                      MaterialPageRoute(
                          builder: (_) => const InquiryListScreen()),
                    );
                  },
                ),
                _InquiryMenuTile(
                  icon: Icons.edit_outlined,
                  label: '문의하기',
                  subtitle: '불편한 점을 알려주세요',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showModalBottomSheet(
                      context: sheetContext,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const _InquirySheet(),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final convProvider = context.watch<ConversationProvider>();

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 프로필 헤더 ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: auth.isLoggedIn
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.surface,
                    backgroundImage: auth.profileImageUrl != null
                        ? NetworkImage(auth.profileImageUrl!)
                        : null,
                    child: auth.profileImageUrl == null
                        ? const Icon(Icons.person,
                        color: AppTheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          auth.userName ?? '사용자',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          auth.userEmail ?? '',
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color:
                          AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      auth.loginProvider ?? 'Google',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
                  : Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.surface,
                    child: Icon(Icons.person,
                        color: AppTheme.primary, size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '로그인이 필요합니다',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '로그인하고 분석 내역을 확인하세요',
                    style: TextStyle(
                        color: AppTheme.textHint, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding:
                        const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text(
                        '로그인하기',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppTheme.divider),

            // ── 새 분석 요청 ─────────────────────────────────
            Visibility(
              visible: auth.isLoggedIn,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: GestureDetector(
                  onTap: _onNewAnalysisTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppTheme.primary,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '새 분석 요청',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Consumer<AnalysisQuotaProvider>(
                                builder: (_, quota, __) => Text(
                                  '오늘 ${quota.remaining}회 남음',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textHint, size: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 최근 분석 내역 헤더 ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
              child: Row(
                children: [
                  const Text(
                    '최근 분석 내역',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                      child: Divider(color: AppTheme.divider, height: 1)),
                  const SizedBox(width: 6),
                  Text(
                    '${convProvider.conversations.length}건',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 10),
                  ),
                ],
              ),
            ),

            // ── 대화 목록 ────────────────────────────────────
            Expanded(
              child: convProvider.isLoading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary))
                  : convProvider.conversations.isEmpty
                  ? const Center(
                  child: Text('분석 내역이 없습니다',
                      style: TextStyle(color: AppTheme.textHint)))
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: convProvider.conversations.length,
                itemBuilder: (context, index) {
                  final conv =
                  convProvider.conversations[index];
                  return conv.isGuest
                      ? _GuestConversationTile(
                      conversation: conv)
                      : _ConversationTile(conversation: conv);
                },
              ),
            ),

            // ── 하단 링크 ────────────────────────────────────
            const Divider(color: AppTheme.divider, height: 1),
            _DrawerBottomLink(
              icon: Icons.people_outline,
              label: '커뮤니티',
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CommunityScreen()),
                  );
                });
              },
            ),
            // ✅ 문의 버튼 — 메뉴 시트로 연결
            _DrawerBottomLink(
              icon: Icons.help_outline,
              label: '문의',
              onTap: _showInquiryMenu,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 로그인 유저 타일
// ══════════════════════════════════════════════════════════════
class _ConversationTile extends StatelessWidget {
  final ConversationItem conversation;
  const _ConversationTile({required this.conversation});

  Color get _riskColor =>
      AppTheme.riskLevelColor(conversation.effectiveRiskLevel);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _tileDecoration(),
      child: ListTile(
        tileColor: Colors.transparent,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minVerticalPadding: 8,
        dense: false,
        leading: _Thumbnail(url: conversation.thumbnailUrl),
        title: Text(
          conversation.title,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            _formatRelativeDate(conversation.createdAt),
            style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _riskColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${conversation.riskLevel}%',
            style: TextStyle(
              color: _riskColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _openResult(context),
      ),
    );
  }

  Future<void> _openResult(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await ApiClient()
          .get('/api/fraud/result/${conversation.sessionId}');

      if (response.statusCode != 200) {
        messenger.showSnackBar(
            SnackBar(content: Text('결과 조회 실패: ${response.statusCode}')));
        return;
      }

      final json =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      final messages = <ChatMessage>[
        ChatMessage(type: 'summary', text: json['summary'] as String? ?? '', isDone: true),
        ChatMessage(type: 'riskScore', text: (json['riskScore'] ?? 0).toString(), isDone: true),
        ChatMessage(type: 'riskLevel', text: json['riskLevel'] as String? ?? '', isDone: true),
        ChatMessage(type: 'psychologicalTactics', text: json['psychologicalTactics'] as String? ?? '', isDone: true),
        ChatMessage(type: 'suspicious', text: json['suspiciousPoints'] as String? ?? '', isDone: true),
        ChatMessage(type: 'action', text: json['recommendedActions'] as String? ?? '', isDone: true),
        ChatMessage(type: 'questions', text: json['additionalQuestions'] as String? ?? '', isDone: true),
      ];

      final rawUrls = json['imageUrls'];
      final imageUrls = rawUrls is List
          ? rawUrls.map((e) => e.toString()).toList()
          : <String>[];

      navigator.pop();
      navigator.push(MaterialPageRoute(
        builder: (_) => AnalysisResultScreen(
          messages: messages,
          imageUrls: imageUrls,
          sessionId: conversation.sessionId,
          feedbackHelpful: json['feedbackHelpful'] as bool?,
          categoryName: json['categoryName'] as String?,
          communityPostId: (json['communityPostId'] as num?)?.toInt(),
        ),
      ));
    } on UnauthorizedException {
      messenger.showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    }
  }
}

// ══════════════════════════════════════════════════════════════
// 게스트 타일
// ══════════════════════════════════════════════════════════════
class _GuestConversationTile extends StatelessWidget {
  final ConversationItem conversation;
  const _GuestConversationTile({required this.conversation});

  Color get _riskColor =>
      AppTheme.riskLevelColor(conversation.effectiveRiskLevel);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _tileDecoration(),
      child: ListTile(
        tileColor: Colors.transparent,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minVerticalPadding: 8,
        dense: false,
        leading: conversation.thumbnailUrl != null
            ? _Thumbnail(url: conversation.thumbnailUrl)
            : ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            color: AppTheme.surfaceDeep,
            child: const Icon(Icons.image_outlined,
                color: AppTheme.textHint, size: 20),
          ),
        ),
        title: Text(
          conversation.title,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            _formatRelativeDate(conversation.createdAt),
            style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _riskColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${conversation.riskLevel}%',
            style: TextStyle(
              color: _riskColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _openGuestResult(context),
      ),
    );
  }

  Future<void> _openGuestResult(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      String? token = conversation.imageToken ??
          await GuestTokenStorage.get(conversation.sessionId);

      if (token == null) {
        final tokenResp = await ApiClient().get(
          '/api/fraud/guest/token/${conversation.sessionId}',
          includeDeviceId: true,
        );
        if (tokenResp.statusCode != 200) {
          messenger.showSnackBar(SnackBar(
              content: Text('결과 조회 실패: ${tokenResp.statusCode}')));
          return;
        }
        final tokenData =
        jsonDecode(utf8.decode(tokenResp.bodyBytes)) as Map<String, dynamic>;
        token = tokenData['imageToken'] as String;
        await GuestTokenStorage.save(conversation.sessionId, token);
      }

      final response = await ApiClient().get(
        '/api/fraud/result/guest/${conversation.sessionId}?token=$token',
      );
      if (response.statusCode != 200) {
        messenger.showSnackBar(SnackBar(
            content: Text('결과 조회 실패: ${response.statusCode}')));
        return;
      }

      final json =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      final messages = <ChatMessage>[
        ChatMessage(type: 'summary', text: json['summary'] ?? '', isDone: true),
        ChatMessage(type: 'riskScore', text: '${json['riskScore'] ?? 0}', isDone: true),
        ChatMessage(type: 'riskLevel', text: json['riskLevel'] ?? '', isDone: true),
        ChatMessage(type: 'psychologicalTactics', text: json['psychologicalTactics'] ?? '', isDone: true),
        ChatMessage(type: 'suspicious', text: json['suspiciousPoints'] ?? '', isDone: true),
        ChatMessage(type: 'action', text: json['recommendedActions'] ?? '', isDone: true),
        ChatMessage(type: 'questions', text: json['additionalQuestions'] ?? '', isDone: true),
      ];

      final rawUrls = json['imageUrls'];
      final imageUrls = rawUrls is List
          ? rawUrls.map((e) => e.toString()).toList()
          : <String>[];

      navigator.pop();
      navigator.push(MaterialPageRoute(
        builder: (_) => AnalysisResultScreen(
          messages: messages,
          imageUrls: imageUrls,
          sessionId: conversation.sessionId,
          feedbackHelpful: null,
          guestImageToken: token,
          categoryName: json['categoryName'] as String?,
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }
}

// ══════════════════════════════════════════════════════════════
// 썸네일
// ══════════════════════════════════════════════════════════════
class _Thumbnail extends StatefulWidget {
  final String? url;
  const _Thumbnail({this.url});

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List?> _load() async {
    if (widget.url == null) return null;
    if (AppImageCache.instance.has(widget.url!)) {
      return AppImageCache.instance.get(widget.url!);
    }
    try {
      final path = widget.url!.replaceFirst(AppConfig.baseUrl, '');
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        AppImageCache.instance.set(widget.url!, response.bodyBytes);
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _placeholder(loading: true);
            }
            if (snapshot.data == null) return _placeholder();
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) => Container(
    color: AppTheme.surfaceDeep,
    child: Center(
      child: loading
          ? const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
            strokeWidth: 1.5, color: AppTheme.primary),
      )
          : const Icon(Icons.image_outlined,
          color: AppTheme.textHint, size: 20),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// 하단 링크 버튼
// ══════════════════════════════════════════════════════════════
class _DrawerBottomLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerBottomLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 문의 메뉴 타일 (문의하기 / 문의 내역 선택용)
// ══════════════════════════════════════════════════════════════
class _InquiryMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _InquiryMenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right,
                color: AppTheme.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 문의 바텀 시트
// ══════════════════════════════════════════════════════════════
class _InquirySheet extends StatefulWidget {
  const _InquirySheet();

  @override
  State<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends State<_InquirySheet> {
  final _controller = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isDone = false;

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final auth = context.read<AuthProvider>();

      final response = await ApiClient().post(
        '/api/inquiry',
        body: {
          'content': _controller.text.trim(),
          if (!auth.isLoggedIn && _emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim(),
        },
        includeDeviceId: true,
        fcmToken: fcmToken,
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() { _isSubmitting = false; _isDone = true; });
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문의 전송에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottom),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _isDone ? _buildDone() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 ─────────────────────────────────────────────
        Row(
          children: [
            const Text(
              '문의하기',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: AppTheme.textHint, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '불편한 점이나 건의사항을 남겨주세요.\n빠르게 확인하고 답변 드리겠습니다.',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),

        // ── 게스트 전용 이메일 입력 ───────────────────────────
        Consumer<AuthProvider>(
          builder: (_, auth, __) => auth.isLoggedIn
              ? const SizedBox.shrink()
              : Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '답변받을 이메일을 입력해주세요 (선택)',
                    hintStyle: TextStyle(
                        color: AppTheme.textHint, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                    prefixIcon: Icon(Icons.email_outlined,
                        color: AppTheme.textHint, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // ── 문의 내용 입력 ───────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDeep,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: TextField(
            controller: _controller,
            maxLines: 5,
            maxLength: 500,
            style:
            const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: '문의 내용을 입력해주세요',
              hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
              counterStyle:
              TextStyle(color: AppTheme.textHint, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── 전송 버튼 ────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              disabledBackgroundColor:
              AppTheme.primary.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('문의 보내기',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.check_circle_outline,
            color: AppTheme.primary, size: 48),
        const SizedBox(height: 14),
        const Text(
          '문의가 접수되었습니다',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '검토 후 빠르게 답변 드리겠습니다.\n답변이 등록되면 알림으로 알려드릴게요.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 바로 문의 내역 화면으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InquiryListScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('문의 내역 보기',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceDeep,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('닫기',
                style:
                TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}