// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../upload/image_upload_screen.dart';
import 'conversation_drawer.dart';
import 'home_body.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        // 햄버거 버튼 (자동으로 Drawer 열림)
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, color: Color(0xFF4FC3F7), size: 20),
            SizedBox(width: 8),
            Text(
              '미리톡',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showProfileMenu(context, auth),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0F3460),
                backgroundImage: auth.profileImageUrl != null
                    ? NetworkImage(auth.profileImageUrl!)
                    : null,
                child: auth.profileImageUrl == null
                    ? const Icon(Icons.person, color: Color(0xFF4FC3F7), size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: const ConversationDrawer(),
      body: const HomeBody(),
    );
  }

  void _showProfileMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF0F3460),
              backgroundImage: auth.profileImageUrl != null
                  ? NetworkImage(auth.profileImageUrl!)
                  : null,
              child: auth.profileImageUrl == null
                  ? const Icon(Icons.person, color: Color(0xFF4FC3F7), size: 36)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              auth.userName ?? '사용자',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              auth.userEmail ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFEF5350)),
              title: const Text('로그아웃', style: TextStyle(color: Color(0xFFEF5350))),
              onTap: () {
                Navigator.pop(context);
                auth.logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}