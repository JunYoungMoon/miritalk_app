// lib/features/notification_guard/models/risk_keyword.dart
// 서버 GET /api/risk/keywords 응답의 keywords[] 1건.
// 클라이언트가 NotificationScorer 로 알림 텍스트와 매칭.
class RiskKeyword {
  final int id;
  final String keyword;
  final String categoryCode;
  final int score;
  final KeywordMatchType matchType;

  /// CONTAINS/EXACT 비교용으로 공백을 제거한 키워드.
  /// 사기범은 "안전계좌" / "안전 계좌" / "안 전 계좌" 처럼 띄어쓰기를 변형해
  /// 정규 키워드와 어긋나게 만든다. 양쪽 모두 공백 제거 후 비교해 이 회피를 차단.
  final String normalizedKeyword;

  // REGEX 일 때 한 번만 컴파일해 보관 (CONTAINS/EXACT 는 null).
  final RegExp? _compiled;

  RiskKeyword({
    required this.id,
    required this.keyword,
    required this.categoryCode,
    required this.score,
    required this.matchType,
    RegExp? compiled,
  })  : _compiled = compiled,
        normalizedKeyword = _stripWhitespace(keyword);

  static final RegExp _wsRe = RegExp(r'\s+');
  static String _stripWhitespace(String s) => s.replaceAll(_wsRe, '');

  factory RiskKeyword.fromJson(Map<String, dynamic> json) {
    final type = KeywordMatchType.parse(json['matchType'] as String? ?? 'CONTAINS');
    final kw = json['keyword'] as String;
    RegExp? compiled;
    if (type == KeywordMatchType.regex) {
      try {
        compiled = RegExp(kw, caseSensitive: false, unicode: true);
      } catch (_) {
        // 서버에 깨진 정규식이 있으면 CONTAINS 로 폴백 — 매칭은 못해도 앱이 죽지는 않게.
        compiled = null;
      }
    }
    return RiskKeyword(
      id: (json['id'] as num).toInt(),
      keyword: kw,
      categoryCode: json['categoryCode'] as String? ?? 'OTHER',
      score: (json['score'] as num).toInt(),
      matchType: type,
      compiled: compiled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'categoryCode': categoryCode,
        'score': score,
        'matchType': matchType.name.toUpperCase(),
      };

  /// 텍스트 본문에 이 키워드가 매칭되는지 반환. matchType 별 분기.
  ///
  /// CONTAINS/EXACT 는 공백을 무시한 비교. NotificationScorer 가 매 호출마다
  /// 텍스트를 정규화하면 비효율이라, 정규화된 텍스트를 미리 받는 오버로드 형태로
  /// 사용한다. 단독 호출 편의를 위해 raw 텍스트도 받음.
  bool matches(String text) {
    if (matchType == KeywordMatchType.regex) {
      return _compiled?.hasMatch(text) ?? false;
    }
    return matchesNormalized(_stripWhitespace(text));
  }

  /// 이미 공백 제거된 텍스트와 비교. REGEX 면 항상 false 반환 (호출자가 분기).
  bool matchesNormalized(String normalizedText) {
    switch (matchType) {
      case KeywordMatchType.contains:
        return normalizedText.contains(normalizedKeyword);
      case KeywordMatchType.exact:
        return normalizedText == normalizedKeyword;
      case KeywordMatchType.regex:
        return false;
    }
  }
}

enum KeywordMatchType {
  contains,
  exact,
  regex;

  static KeywordMatchType parse(String raw) {
    switch (raw.toUpperCase()) {
      case 'EXACT':
        return KeywordMatchType.exact;
      case 'REGEX':
        return KeywordMatchType.regex;
      case 'CONTAINS':
      default:
        return KeywordMatchType.contains;
    }
  }
}
