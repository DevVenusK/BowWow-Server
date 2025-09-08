# BowWow iOS App - Tuist 프로젝트

Tuist를 사용한 BowWow iOS 앱 프로젝트 설정 및 빌드 가이드

## 🚀 Tuist 설치

```bash
# Tuist 설치 (Homebrew)
brew install tuist

# 또는 특정 버전 설치
curl -Ls https://install.tuist.io | bash
```

## 📁 프로젝트 구조

```
BowWowApp/
├── .tuist-version              # Tuist 버전 고정 (4.36.0)
├── Project.swift               # 프로젝트 설정
├── Workspace.swift             # 워크스페이스 설정
├── Tuist/
│   ├── Config.swift           # Tuist 환경 설정
│   └── Dependencies.swift     # 외부 의존성 관리
├── Configurations/
│   ├── Debug.xcconfig         # 디버그 빌드 설정
│   └── Release.xcconfig       # 릴리즈 빌드 설정
├── BowWowApp/                 # 메인 앱 소스
├── BowWowAppTests/            # 단위 테스트
└── BowWowAppUITests/          # UI 테스트
```

## 🛠️ 프로젝트 생성 및 빌드

### 1. 의존성 설치
```bash
cd BowWowApp
tuist install
```

### 2. 프로젝트 생성
```bash
tuist generate
```

### 3. Xcode로 열기
```bash
tuist generate && open BowWow.xcworkspace
```

### 4. 빌드 및 실행
```bash
# CLI에서 빌드
tuist build BowWowApp

# 테스트 실행
tuist test BowWowApp
```

## ⚙️ 주요 설정

### Tuist 버전 고정
- `.tuist-version`: **4.36.0** 사용
- 프로젝트 내에서 일관된 Tuist 버전 보장

### 타겟 구성
1. **BowWowApp** (메인 앱)
   - iOS 18.0+
   - Swift 5.9
   - SwiftUI 기반

2. **BowWowAppTests** (단위 테스트)
   - XCTest 프레임워크
   - 강타입 시스템 테스트

3. **BowWowAppUITests** (UI 테스트)
   - XCUITest 프레임워크
   - 앱 플로우 테스트

### 외부 의존성
```swift
// Swift Package Manager를 통한 의존성 관리
- Tagged (0.10.0+) - 강타입 시스템
- Alamofire (5.8.0+) - 네트워킹
- AsyncAlgorithms (1.0.0+) - 비동기 처리
```

### 서버 연동
- **Shared 모듈**: `../Sources/Shared` 경로 참조
- 서버와 동일한 타입 시스템 공유

## 🎯 개발 스키마

### BowWow-Development
- **디버그 빌드**
- 로컬 서버 연결 (`http://localhost:8000/api`)
- 시뮬레이터 위치: 서울 (37.5665, 126.9780)
- HTTP 통신 허용 (개발용)

### BowWow-Testing  
- **테스트 전용**
- 코드 커버리지 활성화
- 병렬 테스트 실행
- 랜덤 실행 순서

### BowWow-Production
- **릴리즈 빌드**
- 프로덕션 서버 연결 (`https://api.bowwow.com/api`)
- 최적화된 설정

## 📱 빌드 설정

### Debug Configuration
```xcconfig
// 개발용 설정
PRODUCT_BUNDLE_IDENTIFIER = com.bowwow.app.debug
PRODUCT_NAME = BowWow-Dev
API_BASE_URL = http://localhost:8000/api
SWIFT_OPTIMIZATION_LEVEL = -Onone
ENABLE_TESTABILITY = YES
```

### Release Configuration  
```xcconfig
// 프로덕션용 설정
PRODUCT_BUNDLE_IDENTIFIER = com.bowwow.app
PRODUCT_NAME = BowWow
API_BASE_URL = https://api.bowwow.com/api
SWIFT_OPTIMIZATION_LEVEL = -O
SWIFT_COMPILATION_MODE = wholemodule
```

## 🔧 개발 워크플로

### 1. 코드 수정 후 재생성
```bash
tuist generate
```

### 2. 의존성 추가 시
```bash
# Dependencies.swift 수정 후
tuist install
tuist generate
```

### 3. 새로운 타겟 추가 시
```bash
# Project.swift 수정 후
tuist generate
```

### 4. 설정 변경 시
```bash
# xcconfig 파일 수정 후 자동 반영
# 또는 Xcode에서 Clean Build
```

## 🧪 테스트 실행

### 단위 테스트
```bash
tuist test BowWowApp --test-targets BowWowAppTests
```

### UI 테스트
```bash
tuist test BowWowApp --test-targets BowWowAppUITests
```

### 모든 테스트
```bash
tuist test BowWowApp
```

## 📋 주의사항

### 1. 팀 ID 설정 필요
```xcconfig
// Debug.xcconfig, Release.xcconfig에서 수정 필요
DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE
```

### 2. 코드 서명 설정
- **Debug**: Automatic signing
- **Release**: Manual signing (프로비저닝 프로필 필요)

### 3. 서버 연결
- 개발 시: 로컬 서버 실행 필요 (`swift run Gateway`)
- Shared 모듈 경로 확인 (`../Sources/Shared`)

### 4. 시뮬레이터 위치 권한
- Xcode Simulator에서 위치 시뮬레이션 활성화
- Features > Location > Custom Location

## 🔄 CI/CD 통합

### GitHub Actions 예시
```yaml
# .github/workflows/ios.yml
- name: Generate Xcode project
  run: tuist generate

- name: Build app
  run: tuist build BowWowApp

- name: Run tests
  run: tuist test BowWowApp
```

## 📚 추가 정보

- [Tuist 공식 문서](https://docs.tuist.io)
- [Swift Package Manager](https://swift.org/package-manager/)
- [iOS 개발 가이드](https://developer.apple.com/documentation/ios-ipados-release-notes)

---

**Tuist 4.36.0** 기반으로 구성된 현대적이고 확장 가능한 iOS 프로젝트 구조입니다! 🎉