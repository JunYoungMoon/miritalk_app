// lib/features/home/conversation_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/network/api_client.dart';

class ConversationItem {
  final int sessionId;
  final String title;
  final int riskLevel;        // riskScore (0~100)
  final String riskLevelLabel; // 낮음|보통|높음|매우높음
  final String createdAt;

  const ConversationItem({
    required this.sessionId,
    required this.title,
    required this.riskLevel,
    required this.riskLevelLabel,
    required this.createdAt,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as String? ?? '';
    return ConversationItem(
      sessionId: json['sessionId'] as int,
      title: summary.length > 30 ? '${summary.substring(0, 30)}...' : summary,
      riskLevel: json['riskScore'] as int? ?? 0,
      riskLevelLabel: json['riskLevel'] as String? ?? '',
      createdAt: _formatDate(json['createdAt'] as String? ?? ''),
    );
  }

  static String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class ConversationProvider extends ChangeNotifier {
  List<ConversationItem> _conversations = [];
  bool _isLoading = false;
  String? _error;

  List<ConversationItem> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiClient().get('/api/fraud/history?limit=20');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _conversations = data
            .map((e) => ConversationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _error = '내역을 불러오지 못했습니다.';
      }
    } on UnauthorizedException {
      _error = '로그인이 필요합니다.';
    } catch (e) {
      _error = '네트워크 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}