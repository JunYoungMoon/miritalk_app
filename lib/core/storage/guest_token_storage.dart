// lib/core/storage/guest_token_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

class GuestTokenStorage {
  static const _prefix = 'guest_token_';

  // 토큰 저장 (분석 완료 시 호출)
  static Future<void> save(int sessionId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$sessionId', token);
  }

  // 토큰 조회 (히스토리 로드 시 호출)
  static Future<String?> get(int sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$sessionId');
  }

  // 오래된 토큰 정리 (보관할 sessionId 목록 외 삭제)
  static Future<void> cleanup(List<int> validSessionIds) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      final sessionId = int.tryParse(key.replaceFirst(_prefix, ''));
      if (sessionId != null && !validSessionIds.contains(sessionId)) {
        await prefs.remove(key);
      }
    }
  }
}