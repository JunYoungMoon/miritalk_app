// lib/features/home/conversation_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/core/storage/guest_token_storage.dart';
import 'package:miritalk_app/features/home/guest_quota_service.dart';

class ConversationItem {
  final int sessionId;
  final String title;
  final int riskLevel;
  final String? riskLevelLabel;
  final String createdAt;
  final String? thumbnailUrl;
  final bool isGuest;
  final String? imageToken;

  const ConversationItem({
    required this.sessionId,
    required this.title,
    required this.riskLevel,
    this.riskLevelLabel,
    required this.createdAt,
    this.thumbnailUrl,
    this.isGuest = false,
    this.imageToken,
  });

  String get effectiveRiskLevel => riskLevelLabel ?? '$riskLevel';
}

class ConversationProvider extends ChangeNotifier {
  List<ConversationItem> _conversations = [];
  bool _isLoading = false;

  List<ConversationItem> get conversations => _conversations;
  bool get isLoading => _isLoading;

  void clear() {
    _conversations = [];
    notifyListeners();
  }

  // 로그인 유저 히스토리
  Future<void> loadConversations({bool refresh = false}) async {
    if (!refresh && _conversations.isNotEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiClient().get('/api/fraud/history?limit=20');
      if (response.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes)) as List;
        _conversations = data.map((e) => ConversationItem(
          sessionId: e['sessionId'] as int,
          title: e['summary'] as String? ?? '분석 결과',
          riskLevel: e['riskScore'] as int? ?? 0,
          riskLevelLabel: e['riskLevel'] as String?,
          createdAt: _formatDate(e['createdAt'] as String? ?? ''),
          thumbnailUrl: e['thumbnailUrl'] as String?,
          isGuest: false,
        )).toList();
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  // 게스트 히스토리 — deviceId 기반
  Future<void> loadGuestConversations({bool refresh = false}) async {
    if (!refresh && _conversations.isNotEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiClient().get(
        '/api/fraud/history/guest?limit=20',
        includeDeviceId: true,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes)) as List;

        // 유효한 sessionId 목록으로 오래된 토큰 정리
        final sessionIds = data.map((e) => e['sessionId'] as int).toList();
        await GuestTokenStorage.cleanup(sessionIds);

        _conversations = await Future.wait(data.map((e) async {
          final sessionId = e['sessionId'] as int;
          final token = await GuestTokenStorage.get(sessionId);
          debugPrint('[Guest] sessionId=$sessionId token=$token');
          debugPrint('[Guest] thumbnailFileName=${e['thumbnailFileName']}');

          String? thumbnailPath;
          if (token != null && e['thumbnailFileName'] != null) {
            thumbnailPath =
            '/api/fraud/guest/image/$sessionId/${e['thumbnailFileName']}?token=$token';
          }
          debugPrint('[Guest] thumbnailPath=$thumbnailPath');

          return ConversationItem(
            sessionId: sessionId,
            title: e['summary'] as String? ?? '분석 결과',
            riskLevel: e['riskScore'] as int? ?? 0,
            riskLevelLabel: e['riskLevel'] as String?,
            createdAt: _formatDate(e['createdAt'] as String? ?? ''),
            thumbnailUrl: thumbnailPath,
            isGuest: true,
            imageToken: token,
          );
        }));
      }
    } catch (e, stack) {
      debugPrint('[GuestHistory] error: $e');
      debugPrint('[GuestHistory] stack: $stack');
    }

    _isLoading = false;
    notifyListeners();
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}