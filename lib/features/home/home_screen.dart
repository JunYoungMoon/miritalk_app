// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'package:miritalk_app/features/upload/image_upload_screen.dart';
import 'conversation_drawer.dart';
import 'home_body.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(
        title: '미리톡',
        showMenu: true,
        showBack: false,
      ),
      drawer: ConversationDrawer(
          onGoToUpload: () {
            _onGoToUpload(context);
          }
      ),
      body: HomeBody(
        onGoToUpload: () {
          _onGoToUpload(context);
        },
      ),
    );
  }

  void _onGoToUpload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageUploadScreen()),
    );
  }
}