# BowWow Server

위치 기반 신호 서비스를 위한 함수형 마이크로서비스 아키텍처 서버

## 프로젝트 구조

```
BowWow/
├── Sources/
│   ├── Gateway/          # API Gateway (포트: 8000)
│   ├── UserService/      # 사용자 관리 (포트: 8001)
│   ├── LocationService/  # 위치 데이터 처리 (포트: 8002)
│   ├── SignalService/    # 신호 로직 (포트: 8003)
│   ├── PushService/      # 푸시 알림 (포트: 8004)
│   ├── AnalyticsService/ # 통계/로깅 (포트: 8005)
│   └── Shared/          # 공통 타입 및 유틸리티
├── Tests/
├── docker-compose.yml
└── Package.swift
```

## 개발 명령어

### 프로젝트 빌드
```bash
swift build
```

### 특정 서비스 실행
```bash
# Gateway 서비스
swift run Gateway

# User 서비스  
swift run UserService

# Location 서비스
swift run LocationService

# Signal 서비스
swift run SignalService

# Push 서비스
swift run PushService

# Analytics 서비스
swift run AnalyticsService
```

### 테스트 실행
```bash
swift test
```

### 데이터베이스 설정

#### PostgreSQL with PostGIS
```bash
# Docker로 PostgreSQL + PostGIS 실행
docker run --name bowwow-postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=bowwow \
  -p 5432:5432 \
  -d postgis/postgis:latest

# 데이터베이스 마이그레이션
swift run Gateway migrate
```

#### Redis 설정
```bash
# Redis 클러스터 실행
docker run --name bowwow-redis \
  -p 6379:6379 \
  -d redis:alpine
```

### 마이크로서비스 실행 (모든 서비스)
```bash
# 모든 서비스를 백그라운드에서 실행
./scripts/start-all-services.sh

# 모든 서비스 중지
./scripts/stop-all-services.sh
```

## 기술 스택

- **언어**: Swift 5.9+
- **프레임워크**: Vapor 4.0+
- **데이터베이스**: PostgreSQL + PostGIS
- **캐시**: Redis
- **푸시 알림**: APNs (Apple Push Notification service)
- **아키텍처**: 함수형 프로그래밍 + 마이크로서비스

## 환경 변수

```bash
# 데이터베이스
DATABASE_URL=postgresql://username:password@localhost:5432/bowwow

# Redis
REDIS_URL=redis://localhost:6379

# APNs 설정
APNS_KEY_ID=your_key_id
APNS_TEAM_ID=your_team_id
APNS_BUNDLE_ID=com.example.bowwow

# 서비스 포트 설정
GATEWAY_PORT=8000
USER_SERVICE_PORT=8001
LOCATION_SERVICE_PORT=8002
SIGNAL_SERVICE_PORT=8003
PUSH_SERVICE_PORT=8004
ANALYTICS_SERVICE_PORT=8005
```

## API 엔드포인트

### Gateway (8000)
- `GET /health` - 시스템 상태 확인
- `POST /users/register` - 사용자 등록
- `POST /signals` - 신호 전송
- `GET /signals/received/:userId` - 수신 신호 조회

### 개발 가이드라인

1. **함수형 프로그래밍**: 순수 함수, 불변성 원칙 준수
2. **작은 단위**: 각 서비스는 단일 책임만 가짐
3. **확장성**: 수평적 확장을 고려한 설계
4. **강타입 사용**: Type Driven Development 적용, 최대한 강타입 사용
   - Phantom Types 활용하여 컴파일 타임 안전성 보장
   - NewType 패턴으로 원시 타입 래핑
   - Tagged Union으로 상태 표현
   - Generic Types로 타입 안전성 강화
5. **테스트**: 각 함수별 단위 테스트 작성
6. **보안**: 위치 데이터 암호화, 24시간 자동 삭제

### Type Driven Development 원칙
- 컴파일러가 잡을 수 있는 오류는 런타임에서 발생하지 않도록 함
- 비즈니스 로직을 타입으로 표현하여 잘못된 상태를 불가능하게 만듦
- Phantom Types와 Associated Types를 활용하여 타입 레벨에서 제약 조건 표현
- 원시 타입(String, Int 등) 직접 사용 금지, NewType 패턴으로 래핑

## 배포

### Docker Compose
```bash
docker-compose up -d
```

### 개발 환경 실행
```bash
# PostgreSQL + Redis 시작
docker-compose up -d postgres redis

# 모든 마이크로서비스 시작
swift run Gateway &
swift run UserService &
swift run LocationService &
swift run SignalService &
swift run PushService &
swift run AnalyticsService &
```