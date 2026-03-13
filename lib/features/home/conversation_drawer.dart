// lib/features/home/conversation_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'conversation_provider.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class ConversationDrawer extends StatefulWidget {
  const ConversationDrawer({super.key});

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final convProvider = context.watch<ConversationProvider>();

    return Drawer(
      width: MediaQuery.of(context).size.width * 2 / 3,
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.surface,
                    backgroundImage: auth.profileImageUrl != null
                        ? NetworkImage(auth.profileImageUrl!)
                        : null,
                    child: auth.profileImageUrl == null
                        ? const Icon(Icons.person, color: AppTheme.primary)
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
              ),
            ),

            const Divider(color: AppTheme.divider),

            // 새 분석 요청 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tileColor: AppTheme.surface,
                leading: const Icon(Icons.add, color: AppTheme.primary),
                title: const Text(
                  '새 분석 요청',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: convProvider.conversations.length,
                itemBuilder: (context, index) {
                  final conv = convProvider.conversations[index];
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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          conversation.riskLevel >= 70
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline,
          color: conversation.riskLevel >= 70
              ? AppTheme.danger
              : AppTheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        conversation.title,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        conversation.createdAt,
        style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: conversation.riskLevel >= 70
              ? AppTheme.danger.withValues(alpha:0.15)
              : AppTheme.primary.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${conversation.riskLevel}%',
          style: TextStyle(
            color: conversation.riskLevel >= 70
                ? AppTheme.danger
                : AppTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () => Navigator.pop(context),
    );
  }
}