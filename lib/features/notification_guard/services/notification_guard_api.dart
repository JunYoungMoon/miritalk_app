import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:miritalk_app/core/network/api_client.dart';
import 'package:miritalk_app/features/auth/auth_service.dart';
import 'package:miritalk_app/features/notification_guard/models/matched_signal.dart';
import 'package:miritalk_app/features/notification_guard/models/notification_judge_response.dart';

/// /api/risk/judge[/guest] 호출 래퍼.
///
/// 로그인 / 게스트 분기는 access token 보유 여부로 결정한다.
/// SSE 가 아닌 단순 POST 라 일반 ApiClient.post() 만으로 충분.
class NotificationGuardApi {
  NotificationGuardApi._();
  static final NotificationGuardApi instance = NotificationGuardApi._();

  Future<NotificationJudgeResponse?> judge({
    required String packageName,
    required String sender,
    required String text,
    required int localScore,
    required List<MatchedSignal> signals,
  }) async {
    final body = {
      'packageName': packageName,
      'sender': sender,
      'text': text,
      'localScore': localScore,
      'signals': signals.map((s) => s.toJson()).toList(),
    };

    final loggedIn = await AuthService().isLoggedIn();
    final path = loggedIn ? '/api/risk/judge' : '/api/risk/judge/guest';

    try {
      final res = await ApiClient().post(
        path,
        body: body,
        includeDeviceId: !loggedIn,
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return NotificationJudgeResponse.fromJson(json);
      }
      if (res.statusCode == 429) {
        debugPrint('알림 판정 쿼터 초과 — 무음 처리');
        return null;
      }
      debugPrint('알림 판정 실패: status=${res.statusCode}');
      return null;
    } on UnauthorizedException {
      // 세션 만료 — 백그라운드 잡이라 사용자에게 다이얼로그 띄울 수 없음. 다음 알림에 다시 시도.
      debugPrint('알림 판정 401 — 세션 만료, 다음 알림에 재시도');
      return null;
    } catch (e) {
      debugPrint('알림 판정 호출 예외: $e');
      return null;
    }
  }
}
