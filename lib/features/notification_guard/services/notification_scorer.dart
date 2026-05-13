import 'package:miritalk_app/features/notification_guard/models/matched_signal.dart';
import 'package:miritalk_app/features/notification_guard/models/risk_keyword.dart';

/// 알림 본문 텍스트에 위험 키워드 사전을 적용해 누적 점수와 매칭 신호를 계산.
///
/// 카테고리당 최고 점수만 채택 (같은 카테고리 내 두 키워드가 모두 잡혀도
/// 점수 폭증 방지). 카테고리 간에는 그대로 더한다.
///
/// 띄어쓰기 회피 대응: CONTAINS/EXACT 키워드는 공백을 제거한 텍스트와 비교한다.
/// "안전계좌" 사전 키워드가 "안전 계좌로 입금" 같은 변형도 잡도록.
class NotificationScorer {
  static final RegExp _wsRe = RegExp(r'\s+');

  final List<RiskKeyword> _keywords;

  NotificationScorer(this._keywords);

  ScoringResult score(String text) {
    if (text.isEmpty || _keywords.isEmpty) {
      return ScoringResult(total: 0, signals: const []);
    }

    // 매 호출 1회만 정규화하여 N개 키워드에 재사용.
    final normalizedText = text.replaceAll(_wsRe, '');

    // 카테고리별 best 매칭: { categoryCode -> (keyword, score) }
    final Map<String, MatchedSignal> bestByCategory = {};

    for (final kw in _keywords) {
      final hit = kw.matchType == KeywordMatchType.regex
          ? kw.matches(text)                       // 정규식은 원문 비교
          : kw.matchesNormalized(normalizedText);  // 그 외는 정규화 본문 비교
      if (!hit) continue;
      final current = bestByCategory[kw.categoryCode];
      if (current == null || kw.score > current.score) {
        bestByCategory[kw.categoryCode] = MatchedSignal(
          keyword: kw.keyword,
          categoryCode: kw.categoryCode,
          score: kw.score,
        );
      }
    }

    final signals = bestByCategory.values.toList();
    final total = signals.fold<int>(0, (sum, s) => sum + s.score);
    return ScoringResult(total: total, signals: signals);
  }
}

class ScoringResult {
  final int total;
  final List<MatchedSignal> signals;

  const ScoringResult({required this.total, required this.signals});
}
