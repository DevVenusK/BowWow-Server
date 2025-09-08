# BowWow iOS App

위치 기반 신호 서비스를 위한 iOS 클라이언트 앱

## 📱 앱 개요

BowWow는 주변 사용자들과 위치 기반 신호를 주고받을 수 있는 iOS 앱입니다. 
강타입(Strong Typing) 시스템을 활용하여 컴파일 타임 안전성을 보장합니다.

## 🏗️ 아키텍처

### 핵심 특징
- **SwiftUI** 기반 현대적 UI
- **MVVM** 아키텍처 패턴
- **강타입 시스템** (Phantom Types, Tagged Types)
- **함수형 프로그래밍** 원칙
- **서버 공유 타입** (Sources/Shared)

### 주요 컴포넌트

```
BowWowApp/
├── Models/
│   └── AppState.swift          # 앱 전역 상태 관리
├── Views/
│   ├── ContentView.swift       # 메인 탭 뷰
│   ├── HomeView.swift          # 홈 화면 (신호 전송)
│   ├── NearbyUsersView.swift   # 주변 사용자 목록
│   ├── SignalsView.swift       # 수신 신호 목록
│   └── SettingsView.swift      # 설정 화면
├── Services/
│   ├── APIService.swift        # 서버 API 통신
│   ├── LocationManager.swift   # 위치 서비스 관리
│   └── NotificationManager.swift # 푸시 알림 관리
└── Utilities/
    └── Extensions/
```

## 🔧 기능

### ✅ 구현 완료
- [x] SwiftUI 기반 UI 구성 (홈, 주변 사용자, 신호, 설정)
- [x] 위치 권한 관리 및 GPS 추적
- [x] 푸시 알림 권한 및 로컬 알림
- [x] 서버 API 통신 (Alamofire 기반)
- [x] 강타입 시스템 (StrongLocation, ValidatedDistance, UserID)
- [x] 신호 전송/수신 기능
- [x] 주변 사용자 검색
- [x] 앱 상태 관리 (ObservableObject)

### 🔄 향후 개발 예정
- [ ] 실제 앱 아이콘 디자인
- [ ] 런치 스크린 이미지
- [ ] 지도 기반 UI (MapKit)
- [ ] 실시간 WebSocket 연결
- [ ] 백그라운드 모드 최적화
- [ ] 접근성 지원
- [ ] 다국어 지원

## 📋 요구사항

- **iOS 16.0+**
- **Xcode 15.0+**
- **Swift 5.9+**

## 🚀 설치 및 실행

### 1. 프로젝트 클론
```bash
git clone <repository-url>
cd BowWow/BowWowApp
```

### 2. 의존성 설치
```bash
swift package resolve
```

### 3. 서버 실행 (로컬 개발)
```bash
cd ../
swift run Gateway
```

### 4. 앱 빌드 및 실행
Xcode에서 `BowWowApp.xcodeproj` 열고 실행하거나:
```bash
swift build
```

## 🔐 권한 설정

### Info.plist 필요 권한
- `NSLocationWhenInUseUsageDescription` - 위치 서비스
- `UIBackgroundModes` - 백그라운드 알림
- `NSAppTransportSecurity` - HTTP 통신 (개발용)

### 런타임 권한 요청
앱 실행 시 자동으로 다음 권한을 요청합니다:
1. 위치 서비스 권한
2. 푸시 알림 권한

## 📡 API 통신

### 엔드포인트
- `POST /api/users/register` - 사용자 등록
- `POST /api/locations/update` - 위치 업데이트
- `GET /api/locations/nearby/{userID}` - 주변 사용자 조회
- `POST /api/signals` - 신호 전송
- `GET /api/signals/received/{userID}` - 수신 신호 조회
- `POST /api/signals/{signalID}/respond` - 신호 응답

### 강타입 통신
```swift
// 위치 업데이트 예시
let location = try StrongLocation.create(lat: 37.5665, lng: 126.9780)
try await APIService.shared.updateLocation(userID: userID, location: location)
```

## 🧪 테스트

### 단위 테스트 실행
```bash
swift test
```

### 테스트 커버리지
- 강타입 검증 테스트
- 위치 계산 로직 테스트
- API 요청/응답 테스트
- 앱 상태 관리 테스트

## 🎨 UI/UX

### 디자인 시스템
- **컬러**: 오렌지/레드 그라데이션 (신호 버튼)
- **타이포그래피**: SF Pro (시스템 폰트)
- **아이콘**: SF Symbols

### 화면별 기능

#### 홈 화면
- 대형 신호 전송 버튼
- 거리 설정 슬라이더 (1-20km)
- 연결 상태 표시
- 권한 상태 표시

#### 주변 사용자
- 실시간 주변 사용자 목록
- 거리/방향 정보
- Pull-to-refresh

#### 신호
- 수신된 신호 목록
- 신호 응답 기능
- 배지 카운트

#### 설정
- 사용자 정보
- 오프라인 모드 토글
- 거리 단위 선택
- 권한 상태 확인

## 🔧 개발자 도구

### 디버깅
- 위치 시뮬레이션 (Simulator)
- 푸시 알림 테스트
- API 연결 상태 모니터링

### 로깅
```swift
print("📍 위치 업데이트: \(location)")
print("✅ 신호 전송 완료: \(signalID)")
print("❌ API 오류: \(error)")
```

## 📈 성능 최적화

- **위치 업데이트**: 10미터 이상 이동 시에만 업데이트
- **네트워크 요청**: 30초 타임아웃
- **메모리 관리**: @MainActor를 통한 UI 업데이트
- **배터리 절약**: 백그라운드 위치 업데이트 제한

## 🐛 문제 해결

### 자주 발생하는 이슈

1. **위치 권한 거부**
   - 설정 > 개인정보 보호 및 보안 > 위치 서비스 확인

2. **서버 연결 실패**
   - 로컬 서버가 실행 중인지 확인 (포트 8000)
   - 네트워크 연결 상태 확인

3. **푸시 알림 안됨**
   - 알림 권한 허용 확인
   - 디바이스 토큰 등록 확인

## 📱 지원 기기

- **iPhone**: iPhone 12 이상 권장
- **iPad**: iPad (9세대) 이상 권장
- **iPod Touch**: 지원하지 않음 (위치 서비스 필요)

## 🔐 보안

- 위치 데이터 서버 전송 시 암호화
- 사용자 식별 정보 최소화
- 24시간 후 위치 데이터 자동 삭제
- HTTPS 통신 (프로덕션)

## 📄 라이선스

MIT License - 자세한 내용은 LICENSE 파일 참조