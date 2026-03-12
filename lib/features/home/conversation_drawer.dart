// lib/features/home/conversation_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'conversation_provider.dart';

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
      backgroundColor: const Color(0xFF16213E),
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
                    backgroundColor: const Color(0xFF0F3460),
                    backgroundImage: auth.profileImageUrl != null
                        ? NetworkImage(auth.profileImageUrl!)
                        : null,
                    child: auth.profileImageUrl == null
                        ? const Icon(Icons.person, color: Color(0xFF4FC3F7))
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
                            color: Colors.white,
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

            const Divider(color: Colors.white12),

            // 새 분석 요청 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tileColor: const Color(0xFF0F3460),
                leading: const Icon(Icons.add, color: Color(0xFF4FC3F7)),
                title: const Text(
                  '새 분석 요청',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ),

            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '최근 분석 내역',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),

            // 대화 목록
            Expanded(
              child: convProvider.isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4FC3F7)),
              )
                  : convProvider.conversations.isEmpty
                  ? const Center(
                child: Text(
                  '분석 내역이 없습니다',
                  style: TextStyle(color: Colors.white38),
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
          color: const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          conversation.riskLevel >= 70
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline,
          color: conversation.riskLevel >= 70
              ? const Color(0xFFEF5350)
              : const Color(0xFF4FC3F7),
          size: 20,
        ),
      ),
      title: Text(
        conversation.title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        conversation.createdAt,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: conversation.riskLevel >= 70
              ? const Color(0xFFEF5350).withOpacity(0.15)
              : const Color(0xFF4FC3F7).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${conversation.riskLevel}%',
          style: TextStyle(
            color: conversation.riskLevel >= 70
                ? const Color(0xFFEF5350)
                : const Color(0xFF4FC3F7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () => Navigator.pop(context),
    );
  }
}