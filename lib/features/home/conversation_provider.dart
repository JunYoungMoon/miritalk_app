// lib/features/home/conversation_provider.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/app_config.dart';

class ConversationItem {
  final String id;
  final String title;
  final int riskLevel;
  final String createdAt;

  const ConversationItem({
    required this.id,
    required this.title,
    required this.riskLevel,
    required this.createdAt,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: json['id'].toString(),
      title: json['title'] ?? '분석 결과',
      riskLevel: json['riskLevel'] ?? 0,
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class ConversationProvider extends ChangeNotifier {
  List<ConversationItem> _conversations = [];
  bool _isLoading = false;

  List<ConversationItem> get conversations => _conversations;
  bool get isLoading => _isLoading;

  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/conversations'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _conversations = data.map((e) => ConversationItem.fromJson(e)).toList();
      }
    } catch (e) {
      // 에러 처리 — 빈 목록 유지
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}