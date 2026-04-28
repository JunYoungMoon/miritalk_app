// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';
import 'package:miritalk_app/core/widgets/common_app_bar.dart';
import 'package:miritalk_app/features/upload/image_upload_screen.dart';
import 'package:miritalk_app/core/update/app_update_service.dart';
import 'package:miritalk_app/core/update/update_dialog.dart';
import 'package:miritalk_app/core/ads/ad_manager.dart';
import 'package:miritalk_app/core/ads/banner_ad_widget.dart';
import 'conversation_drawer.dart';
import 'home_body.dart';
import 'package:provider/provider.dart';
import 'package:miritalk_app/features/auth/auth_provider.dart';
import 'package:miritalk_app/features/home/analysis_quota_provider.dart';
import 'package:miritalk_app/features/home/conversation_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    final result = await AppUpdateService().checkVersion();
    if (result == null || !mounted) return;

    if (result.forceUpdate || result.optionalUpdate) {
      await UpdateDialog.show(
        context,
        forceUpdate: result.forceUpdate,
        latestVersion: result.latestVersion,
        storeUrl: result.storeUrl,
      );
    }
  }

  Future<void> _onGoToUpload() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageUploadScreen()),
    );
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    // 로그인/게스트 구분 없이 항상 갱신
    context.read<AnalysisQuotaProvider>().loadQuota(isLoggedIn: auth.isLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CommonAppBar(
        title: '미리톡',
        showMenu: true,
        showBack: false,
      ),
      drawer: ConversationDrawer(onGoToUpload: _onGoToUpload),
      onDrawerChanged: (isOpened) {
        if (!isOpened) return;
        final auth = context.read<AuthProvider>();
        final conv = context.read<ConversationProvider>();
        if (auth.isLoggedIn) {
          conv.loadConversations();
        } else {
          conv.loadGuestConversations();
        }
      },
      body: SafeArea(
        child: HomeBody(onGoToUpload: _onGoToUpload),
      ),
      bottomNavigationBar: const BannerAdWidget(placementKey: AdPlacements.homeBanner),
    );
  }
}