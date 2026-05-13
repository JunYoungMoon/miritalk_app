// 클라이언트가 알림 텍스트에서 매칭한 위험 신호 1건.
// /api/risk/judge 요청의 signals[] 요소로 직렬화된다.
class MatchedSignal {
  final String keyword;
  final String categoryCode;
  final int score;

  const MatchedSignal({
    required this.keyword,
    required this.categoryCode,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'keyword': keyword,
        'categoryCode': categoryCode,
        'score': score,
      };
}
