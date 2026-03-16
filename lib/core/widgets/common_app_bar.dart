// lib/core/widgets/common_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool showMenu;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.showMenu = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _showProfileMenu(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
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
              backgroundColor: AppTheme.surfaceDeep,
              backgroundImage: auth.profileImageUrl != null
                  ? NetworkImage(auth.profileImageUrl!)
                  : null,
              child: auth.profileImageUrl == null
                  ? const Icon(Icons.person, color: AppTheme.primary, size: 36)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              auth.userName ?? '사용자',
              style: const TextStyle(
                color: AppTheme.textPrimary,
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
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text('로그아웃',
                  style: TextStyle(color: AppTheme.danger)),
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
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      )
          : showBack
          ? IconButton(
        icon: const Icon(Icons.chevron_left,
            color: Colors.white, size: 28),
        onPressed: () => Navigator.pop(context),
      )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.security, color: AppTheme.primary, size: 20),
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
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _showProfileMenu(context),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surfaceDeep,
              backgroundImage: auth.profileImageUrl != null
                  ? NetworkImage(auth.profileImageUrl!)
                  : null,
              child: auth.profileImageUrl == null
                  ? const Icon(Icons.person, color: AppTheme.primary, size: 20)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}