// lib/features/home/conversation_drawer.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'conversation_provider.dart';
import 'analysis_quota_provider.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/features/analysis/analysis_result_screen.dart';
import 'package:miritalk_app/core/config/app_config.dart';
import 'package:miritalk_app/core/storage/guest_token_storage.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'dart:typed_data';
import 'package:miritalk_app/core/cache/app_image_cache.dart';

class ConversationDrawer extends StatefulWidget {
  final VoidCallback onGoToUpload;
  const ConversationDrawer({super.key, required this.onGoToUpload});

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  @override
  void initState() {
    super.initState();
  }

  // 새 분석 요청 버튼 탭 핸들러
  Future<void> _onNewAnalysisTap() async {
    final auth = context.read<AuthProvider>();
    final quotaProvider = context.read<AnalysisQuotaProvider>();

    if (!auth.isLoggedIn) {
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    await quotaProvider.loadQuota(isLoggedIn: true);
    if (!mounted) return;

    if (quotaProvider.isExhausted) {
      Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오늘 분석 횟수를 모두 사용했습니다. 내일 다시 이용해주세요.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    Navigator.pop(context);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    widget.onGoToUpload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final convProvider = context.watch<ConversationProvider>();

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: auth.isLoggedIn
                  ? Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.surfaceDeep,
                    backgroundImage: auth.profileImageUrl != null
                        ? NetworkImage(auth.profileImageUrl!)
                        : null,
                    child: auth.profileImageUrl == null
                        ? const Icon(Icons.person,
                        color: AppTheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.userName ?? '사용자',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          auth.userEmail ?? '',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.surfaceDeep,
                    child: const Icon(Icons.person,
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
                    style:
                    TextStyle(color: AppTheme.textHint, fontSize: 11),
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
                              builder: (_) => const LoginScreen()),
                        );
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

            // 새 분석 요청 버튼
            Visibility(
              visible: auth.isLoggedIn,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  tileColor: AppTheme.surfaceDeep,
                  leading: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppTheme.primary),
                  title: const Text(
                    '새 분석 요청',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: _onNewAnalysisTap,
                ),
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const Text(
                    '최근 분석 내역',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                  ),
                  if (!auth.isLoggedIn) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '기기 저장',
                        style: TextStyle(color: AppTheme.primary, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 대화 목록
            Expanded(
              child: convProvider.isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary),
              )
                  : convProvider.conversations.isEmpty
                  ? const Center(
                child: Text(
                  '분석 내역이 없습니다',
                  style: TextStyle(color: AppTheme.textHint),
                ),
              )
                  : ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 12),
                itemCount: convProvider.conversations.length,
                itemBuilder: (context, index) {
                  final conv = convProvider.conversations[index];
                  return conv.isGuest
                      ? _GuestConversationTile(conversation: conv)
                      : _ConversationTile(conversation: conv);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationItem conversation;
  const _ConversationTile({required this.conversation});

  Color get _riskColor =>
      AppTheme.riskLevelColor(conversation.effectiveRiskLevel);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      minVerticalPadding: 4,
      dense: true,
      leading: _Thumbnail(url: conversation.thumbnailUrl),
      title: Text(
        conversation.title,
        style:
        const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          conversation.createdAt,
          style:
          const TextStyle(color: AppTheme.textHint, fontSize: 10),
        ),
      ),
      trailing: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  Future<void> _openResult(BuildContext context) async {
    // ✅ pop 전에 navigator 참조를 저장
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await ApiClient()
          .get('/api/fraud/result/${conversation.sessionId}');

      if (response.statusCode != 200) {
        messenger.showSnackBar(
          SnackBar(content: Text('결과 조회 실패: ${response.statusCode}')),
        );
        return;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes))
      as Map<String, dynamic>;

      final messages = <ChatMessage>[
        ChatMessage(
            type: 'summary',
            text: json['summary'] as String? ?? '',
            isDone: true),
        ChatMessage(
            type: 'riskScore',
            text: (json['riskScore'] ?? 0).toString(),
            isDone: true),
        ChatMessage(
            type: 'riskLevel',
            text: json['riskLevel'] as String? ?? '',
            isDone: true),
        ChatMessage(
            type: 'psychologicalTactics',
            text: json['psychologicalTactics'] as String? ?? '',
            isDone: true),
        ChatMessage(
            type: 'suspicious',
            text: json['suspiciousPoints'] as String? ?? '',
            isDone: true),
        ChatMessage(
            type: 'action',
            text: json['recommendedActions'] as String? ?? '',
            isDone: true),
        ChatMessage(
            type: 'questions',
            text: json['additionalQuestions'] as String? ?? '',
            isDone: true),
      ];

      final rawUrls = json['imageUrls'];
      final imageUrls = rawUrls is List
          ? rawUrls.map((e) => e.toString()).toList()
          : <String>[];

      navigator.pop();

      navigator.push(
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(
            messages: messages,
            imageUrls: imageUrls,
            sessionId: conversation.sessionId,
            feedbackHelpful: json['feedbackHelpful'] as bool?,
            categoryName: json['categoryName'] as String?,
          ),
        ),
      );
    } on UnauthorizedException {
      messenger.showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
    } catch (e, stack) {
      messenger.showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }
}

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
    } catch (e) {}
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
          strokeWidth: 1.5,
          color: AppTheme.primary,
        ),
      )
          : const Icon(Icons.image_outlined,
          color: AppTheme.textHint, size: 20),
    ),
  );
}

class _GuestConversationTile extends StatelessWidget {
  final ConversationItem conversation;
  const _GuestConversationTile({required this.conversation});

  Color get _riskColor =>
      AppTheme.riskLevelColor(conversation.effectiveRiskLevel);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      dense: true,
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
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          conversation.createdAt,
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
    );
  }

  Future<void> _openGuestResult(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 로컬 저장소에서 토큰 먼저 조회
      String? token = conversation.imageToken
          ?? await GuestTokenStorage.get(conversation.sessionId);

      // 로컬에 없으면 서버에서 발급
      if (token == null) {
        final tokenResp = await ApiClient().get(
          '/api/fraud/guest/token/${conversation.sessionId}',
          includeDeviceId: true,
        );

        if (tokenResp.statusCode != 200) {
          messenger.showSnackBar(
            SnackBar(content: Text('결과 조회 실패: ${tokenResp.statusCode}')),
          );
          return;
        }

        final tokenData =
        jsonDecode(utf8.decode(tokenResp.bodyBytes)) as Map<String, dynamic>;
        token = tokenData['imageToken'] as String;

        // 발급받은 토큰 로컬에 저장
        await GuestTokenStorage.save(conversation.sessionId, token);
      }

      // 토큰으로 결과 상세 조회
      final response = await ApiClient().get(
        '/api/fraud/result/guest/${conversation.sessionId}?token=$token',
      );

      if (response.statusCode != 200) {
        messenger.showSnackBar(
          SnackBar(content: Text('결과 조회 실패: ${response.statusCode}')),
        );
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