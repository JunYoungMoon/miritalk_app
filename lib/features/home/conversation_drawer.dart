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
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'dart:typed_data';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().loadConversations();
    });
  }

  /// 새 분석 요청 버튼 탭 핸들러
  Future<void> _onNewAnalysisTap() async {
    final auth = context.read<AuthProvider>();
    final quotaProvider = context.read<AnalysisQuotaProvider>();

    Navigator.pop(context); // 드로어 닫기

    // ── 1. 로그인 체크 ──
    if (!auth.isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // ── 2. 쿼터 최신화 후 소진 여부 확인 ──
    await quotaProvider.loadQuota();
    if (!mounted) return;

    if (quotaProvider.isExhausted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오늘 분석 횟수를 모두 사용했습니다. 내일 다시 이용해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    widget.onGoToUpload();

    // // ── 3. 업로드 화면으로 이동, 완료 후 quota 재조회 ──
    // await Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (_) => const ImageUploadScreen()),
    // );
    //
    // // 화면에서 돌아왔을 때 quota 갱신 (분석이 실제로 이뤄졌을 수도 있으므로)
    // if (mounted) {
    //   await quotaProvider.loadQuota();
    //   await context.read<ConversationProvider>().loadConversations();
    // }
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
                              color: Colors.white54, fontSize: 12),
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
                    TextStyle(color: Colors.white38, fontSize: 11),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '최근 분석 내역',
                style: TextStyle(color: AppTheme.textHint, fontSize: 12),
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
                  final conv =
                  convProvider.conversations[index];
                  return _ConversationTile(conversation: conv);
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
    Navigator.pop(context);
    try {
      final response = await ApiClient()
          .get('/api/fraud/result/${conversation.sessionId}');
      if (response.statusCode != 200) return;

      final json = jsonDecode(utf8.decode(response.bodyBytes))
      as Map<String, dynamic>;

      final messages = <ChatMessage>[
        ChatMessage(
            type: 'summary',
            text: json['summary'] ?? '',
            isDone: true),
        ChatMessage(
            type: 'riskScore',
            text: json['riskScore'].toString(),
            isDone: true),
        ChatMessage(
            type: 'riskLevel',
            text: json['riskLevel'] ?? '',
            isDone: true),
        ChatMessage(
            type: 'suspicious',
            text: json['suspiciousPoints'] ?? '',
            isDone: true),
        ChatMessage(
            type: 'action',
            text: json['recommendedActions'] ?? '',
            isDone: true),
        ChatMessage(
            type: 'questions',
            text: json['additionalQuestions'] ?? '',
            isDone: true),
      ];

      final rawUrls = json['imageUrls'];
      final imageUrls = rawUrls is List
          ? rawUrls.map((e) => e.toString()).toList()
          : <String>[];

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(
              messages: messages,
              imageUrls: imageUrls,
              sessionId: conversation.sessionId,
              feedbackHelpful: json['feedbackHelpful'] as bool?,
            ),
          ),
        );
      }
    } on UnauthorizedException {
      debugPrint('인증 오류');
    } catch (e) {
      debugPrint('결과 조회 실패: $e');
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
    try {
      final path =
      widget.url!.replaceFirst(AppConfig.baseUrl, '');
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) return response.bodyBytes;
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
          strokeWidth: 1.5,
          color: AppTheme.primary,
        ),
      )
          : const Icon(Icons.image_outlined,
          color: AppTheme.textHint, size: 20),
    ),
  );
}