# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

**미리톡(miritalk_app)** — 대화 스크린샷을 업로드하면 서버가 사기 위험도를 판정해주는 Flutter 모바일 앱. Android/iOS 타깃, 다크 모드 고정, 세로 방향 고정.

## 개발 명령어

```bash
# 의존성 설치
flutter pub get

# 개발 실행 (Android 에뮬레이터는 baseUrl이 10.0.2.2:8081로 잡힘)
flutter run --dart-define=ENV=dev \
  --dart-define=GOOGLE_CLIENT_ID=... \
  --dart-define=KAKAO_NATIVE_APP_KEY=... \
  --dart-define=MIXPANEL_TOKEN=...

# 프로덕션 실행 (baseUrl = https://miritalk.com)
flutter run --dart-define=ENV=prod --dart-define=...

# 정적 분석 (flutter_lints 기반)
flutter analyze

# 테스트 전체 / 단일 파일 / 단일 케이스
flutter test
flutter test test/widget_test.dart
flutter test --plain-name "테스트 이름"

# 릴리스 빌드
flutter build apk --release --dart-define=ENV=prod --dart-define=...
flutter build appbundle --release --dart-define=ENV=prod --dart-define=...
flutter build ios --release --dart-define=ENV=prod --dart-define=...

# 런처 아이콘 / 스플래시 재생성 (pubspec.yaml 설정 반영)
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

`--dart-define` 값은 `lib/core/config/app_config.dart`의 `String.fromEnvironment()`로 컴파일 타임에 주입됨. 누락하면 Google/Kakao 로그인, Mixpanel 초기화가 조용히 실패한다.

Android 릴리스 서명은 `android/app/key.properties`와 `miritalk-key.keystore`에 의존하며, 카카오 네이티브 앱 키는 `android/local.properties`의 `kakaoNativeAppKey`가 `AndroidManifest`로 주입된다 (`android/app/build.gradle.kts`).

## 아키텍처

### 레이어 구성 — `lib/core` + `lib/features`

`lib/main.dart`가 Firebase, Mixpanel, Kakao SDK를 초기화한 뒤 `MultiProvider`로 세 개의 최상위 Provider를 꽂고 `MaterialApp`을 실행한다.

- **`lib/core/`** — 기능 횡단 인프라. 모든 feature가 여기에 의존한다.
  - `config/app_config.dart` — 환경 분기 (`ENV` dart-define), baseUrl, 시크릿 키 상수
  - `network/api_client.dart` — HTTP 싱글턴. 아래 "인증/네트워킹" 참고
  - `notifications/fcm_service.dart` — FCM + `flutter_local_notifications` 래퍼
  - `tracking/` — `TrackingService`(Firebase Analytics), `MixpanelService`, `ScreenTimeTracker`
  - `storage/guest_token_storage.dart` — 게스트 이미지 접근 토큰을 `SharedPreferences`에 sessionId별로 저장
  - `cache/app_image_cache.dart` — 메모리 기반 URL→바이트 캐시. 로그인/로그아웃 시 반드시 `clear()` 호출 (다른 계정 이미지 오염 방지)
  - `theme/app_theme.dart` — 다크 전용 팔레트 (네이비 배경 + 퍼플 primary), 위험도 색상 상수
  - `update/` — `/api/version` 기반 강제/선택 업데이트 체크
  - `ads/`, `widgets/`, `utils/`

- **`lib/features/`** — 도메인별 화면/Provider/서비스. feature 간 import는 허용되어 있으며 (auth ↔ home, analysis ↔ community 등 실제로 교차한다), core로만 단방향 의존하는 구조는 아니다.
  - `auth/` — Google + Kakao 소셜 로그인 (`AuthService`, `AuthProvider`)
  - `home/` — 홈 화면, 대화 히스토리 Drawer (`ConversationProvider`), 일일 쿼터 (`AnalysisQuotaProvider`), 게스트 디바이스ID 조회 (`GuestQuotaService`)
  - `upload/` — 갤러리 피커 및 이미지 선택 (최대 5장, `AppConfig.maxImages`)
  - `analysis/` — SSE 스트리밍 분석 화면 (`AnalyzingScreen`)과 결과 화면 (`AnalysisResultScreen`)
  - `community/`, `inquiry/`, `settings/`, `consent/`

### 상태 관리

`provider` 패키지의 `ChangeNotifier` + `MultiProvider` 패턴. 최상위에 꽂히는 세 Provider:
- `AuthProvider` — 로그인 상태, 프로필, access/refresh 토큰. `setConversationProvider()`로 **ConversationProvider를 주입받아** 로그인/로그아웃/탈퇴 시 히스토리를 강제 갱신하거나 비운다. `main.dart`에서 이 와이어링을 먼저 해야 한다.
- `ConversationProvider` — 회원/게스트용 히스토리를 한 리스트에서 관리. `loadConversations()` vs `loadGuestConversations()`를 로그인 여부에 따라 골라 부른다 (`HomeScreen.onDrawerChanged`).
- `AnalysisQuotaProvider` — 일일 분석 횟수. 업로드 화면 복귀 시 `loadQuota(isLoggedIn: ...)`로 다시 불러와야 UI가 맞는다.

### 인증/네트워킹 — 반드시 `ApiClient`를 경유

`lib/core/network/api_client.dart`의 **싱글턴 `ApiClient`**가 모든 API 호출의 단일 진입점이다. 직접 `http.get/post`를 쓰는 코드는 로그인 엔드포인트 (`/api/auth/google`, `/api/auth/kakao`, `/api/auth/reissue`, `/api/auth/withdraw`)와 FCM 토큰 등록 (`AuthService._registerFcmToken`)에만 한정되어 있다. 새 API를 붙일 때는 반드시 `ApiClient`를 써야 아래 동작이 자동으로 붙는다.

- `flutter_secure_storage`의 `access_token`(`AppConfig.tokenKey`)을 자동으로 `Authorization: Bearer`에 붙인다.
- **401 처리**: `_handleUnauthorized`가 `refreshToken`으로 `/api/auth/reissue`를 호출해 재발급 후 원래 요청을 재시도한다. 실패 시 `UnauthorizedException`을 던진다. SSE 스트림(`postMultipartStream`)에도 동일 로직이 구현되어 있다. **UI 단의 처리는 호출 맥락에 따라 갈린다** — 부수적 데이터 로드(히스토리, 쿼터)는 SnackBar 안내 또는 무음 fallback 으로 화면을 유지하지만, 사용자가 명시적으로 시작한 핵심 액션(분석 시작 등)은 "세션이 만료되었습니다…" 다이얼로그를 띄운 뒤 확인을 누르면 `LoginScreen` 으로 `pushReplacement` 한다 (예: `image_upload_screen.dart` 의 `_showErrorDialog(message, onConfirm: ...)` + `barrierDismissible: false`). 즉시 라우팅하면 사용자가 맥락을 잃으므로 새 핵심 액션도 이 관행을 따른다.
- **게스트 분기**: 비로그인 상태에서 `includeDeviceId: true`로 호출하면 `GuestQuotaService.getAndroidId()`로 Android ID를 읽어 `X-Device-Id` 헤더로 붙인다 (Android 전용, iOS는 null). 서버는 이 ID로 게스트 쿼터와 히스토리를 식별한다.
- **SSE 분석**: `postMultipartStream`은 `Accept: text/event-stream`으로 보내고 `http.StreamedResponse`를 반환한다. `AnalyzingScreen`은 `utf8.decoder → LineSplitter`로 `data:` 라인을 파싱한다. 413은 `FileTooLargeException`, 429는 `QuotaExceededException(message)`로 즉시 throw — 호출부는 이 두 예외를 반드시 분리해서 처리해야 UX가 맞는다.

### 게스트 vs 로그인 이중 경로

이 앱의 가장 까다로운 점은 **비로그인 사용자도 분석을 1회 무료로 쓸 수 있다**는 점이다. 서버/클라이언트 양쪽에 병행 경로가 있다:

- 엔드포인트가 쌍으로 분리됨: `/api/fraud/analyze` ↔ `/api/fraud/analyze/guest`, `/api/fraud/history` ↔ `/api/fraud/history/guest`, `/api/fraud/result/$id` ↔ `/api/fraud/result/guest/$id?token=...`
- 게스트 이미지/결과 접근은 **세션별 일회용 토큰**을 서버가 발급 → 클라이언트가 `GuestTokenStorage`에 `guest_token_{sessionId}` 키로 저장 → 히스토리 로드 시 꺼내서 썸네일 URL에 쿼리스트링으로 붙인다. 히스토리 응답에 없는 sessionId 토큰은 `cleanup()`으로 자동 삭제된다.
- 게스트 분석 시 FCM 토큰을 `X-FCM-Token` 헤더로 같이 보내야 서버가 푸시로 완료 알림을 쏠 수 있다 (`AnalyzingScreen`이 업로드 화면에서 넘겨받은 `guestFcmToken`을 전달).
- 코드 작성 시 로그인 분기 → 게스트 분기를 둘 다 검토해야 함. 한쪽만 고치면 게스트 UX가 조용히 깨진다.

### 푸시 알림 → 딥링크

`FcmService.initialize()`는 `onAnalysisComplete(sessionId, imageToken)`과 `onInquiryReply` 콜백을 받는다. `main.dart`에서 전역 `navigatorKey`를 통해 `/result`(분석 완료) 또는 `InquiryListScreen`(문의 답변)으로 라우팅한다. 페이로드 타입은 `message.data['type']` (`INQUIRY_REPLY`)으로 분기한다. 백그라운드/종료 상태에서의 탭도 `getInitialMessage()`로 처리하므로 `HomeScreen`이 탑 라우트로 올라온 뒤에 동작하도록 500ms 지연이 들어가 있다.

### Firebase & 트래킹

- Firebase 프로젝트: `miritalk-d1dc6` (`firebase.json`, `lib/firebase_options.dart`). Crashlytics, Analytics, Messaging 모두 활성화.
- `TrackingService`(Firebase Analytics)와 `MixpanelService`가 이벤트를 **동시에** 쏜다. 새 이벤트 추가 시 양쪽 정의를 확인할 것. `ScreenTimeTracker`는 각 화면 `initState`에서 생성, `dispose`에서 자동으로 체류시간 이벤트를 날린다.

### 테마와 UI 규칙

- 다크 모드 고정 (`themeMode: ThemeMode.dark`). 라이트 팔레트도 `AppTheme`에 정의돼 있지만 실사용 안 함.
- `MaterialApp.builder`에서 `textScaler: TextScaler.linear(1.2)`로 전체 폰트를 1.2배 스케일함. 신규 UI 크기 계산 시 이 점을 고려할 것.
- 위험도 표기는 `AppTheme.riskHigh/riskMedium/riskLow` 색상 + `ConversationItem.effectiveRiskLevel` (서버 라벨 우선, 없으면 점수 문자열).
