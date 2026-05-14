// lib/features/notification_guard/models/notification_judge_response.dart
// 서버 POST /api/risk/judge[/guest] 응답.
class NotificationJudgeResponse {
  final String verdict;        // "SAFE" | "SUSPICIOUS"
  final int riskScore;         // 0~100
  final String summary;        // 1~2문장
  final List<String> reasons;

  const NotificationJudgeResponse({
    required this.verdict,
    required this.riskScore,
    required this.summary,
    required this.reasons,
  });

  bool get isSuspicious => verdict == 'SUSPICIOUS';

  factory NotificationJudgeResponse.fromJson(Map<String, dynamic> json) {
    final reasonsRaw = json['reasons'];
    final reasons = <String>[];
    if (reasonsRaw is List) {
      for (final r in reasonsRaw) {
        if (r is String) reasons.add(r);
      }
    }
    return NotificationJudgeResponse(
      verdict: json['verdict'] as String? ?? 'SAFE',
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? '',
      reasons: reasons,
    );
  }
}
