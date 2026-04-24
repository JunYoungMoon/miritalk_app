// lib/core/widgets/common_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/auth/login_screen.dart';
import 'package:miritalk_app/features/home/conversation_provider.dart';
import 'package:miritalk_app/features/settings/settings_bottom_sheet.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool showMenu;
  final List<Widget> extraActions;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.showMenu = false,
    this.extraActions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _showProfileMenu(BuildContext context) {
    final auth = context.read<AuthProvider>();

    // 비로그인 → 로그인 화면으로
    if (!auth.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    SettingsBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showMenu
          ? Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      )
          : showBack
          ? IconButton(
        icon: const Icon(Icons.chevron_left,
            color: AppTheme.textPrimary, size: 28),
        onPressed: () => Navigator.pop(context),
      )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Image.asset(
              'assets/icons/app_icon5.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        ...extraActions,
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _showProfileMenu(context),
            child: auth.isLoggedIn
            // 로그인 상태 — 프로필 아바타
                ? CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surfaceDeep,
              backgroundImage: auth.profileImageUrl != null
                  ? NetworkImage(auth.profileImageUrl!)
                  : null,
              child: auth.profileImageUrl == null
                  ? const Icon(Icons.person,
                  color: AppTheme.primary, size: 20)
                  : null,
            )
            // 비로그인 상태 — 로그인 텍스트 버튼
                : Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: const Text(
                '로그인',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}