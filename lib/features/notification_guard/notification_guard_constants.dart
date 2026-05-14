// lib/features/notification_guard/notification_guard_constants.dart
//
// 알림 사기 사전 차단 임계값 공통 정의.
// `NotificationGuardService` 와 `NotificationBuffer` 양쪽이 같은 값을 봐야 해서
// 한쪽만 바꿔도 다른 쪽이 어긋나지 않도록 여기서만 관리한다.

/// 서버 판정 호출 임계 점수. 점수 가이드 기준 50 이 표준.
/// 테스트할 때만 30 정도로 낮춰서 흐름 확인, 출시 시점에 50 복귀.
/// 운영 데이터 보고 false positive 가 많으면 60~70 으로 보수화.
const int kNotificationGuardThresholdScore = 50;

/// 같은 (key, text) 가 이 시간 내 다시 오면 무시 (안드로이드 알림 갱신 dedup).
const Duration kNotificationGuardDedupWindow = Duration(seconds: 2);

/// 같은 키에서 이 시간 동안 새 알림이 없으면 그동안 모인 버퍼를 1회 flush.
const Duration kNotificationGuardQuietGap = Duration(seconds: 5);

/// 첫 알림 이후 최대 보관 시간. 넘으면 강제 flush + 리셋.
const Duration kNotificationGuardMaxWindow = Duration(seconds: 60);

/// flush 트리거 후 같은 키에 적용되는 쿨다운.
const Duration kNotificationGuardCooldown = Duration(seconds: 60);

/// 버퍼 텍스트 최대 길이. 활성 단톡방에서 quadratic 재스코어링 spike 방지용.
const int kNotificationGuardMaxBufferChars = 2000;
