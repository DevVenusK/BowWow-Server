# BowWow 프로덕션 환경 설정 가이드

## 🚀 프로덕션 배포 준비사항

### 1. Apple Push Notification Service (APNS) 설정

#### 필요한 환경 변수:
```bash
# Apple 개발자 계정 정보
export APNS_KEY_ID="ABCDEFGHIJ"          # Apple에서 생성한 Key ID
export APNS_TEAM_ID="1234567890"         # Apple Team ID
export APNS_KEY_PATH="/path/to/AuthKey_ABCDEFGHIJ.p8"  # P8 키 파일 경로
export APNS_TOPIC="com.yourcompany.bowwow"    # Bundle Identifier

# 프로덕션 환경 설정
export VAPOR_ENV="production"
```

#### APNS 키 생성 절차:
1. [Apple Developer Console](https://developer.apple.com/) 로그인
2. Certificates, Identifiers & Profiles 메뉴 선택
3. Keys 메뉴에서 "+" 버튼 클릭
4. "Apple Push Notifications service (APNs)" 체크
5. Key 이름 입력 후 Register
6. AuthKey_XXXXXXXXX.p8 파일 다운로드
7. Key ID와 Team ID 기록

### 2. 데이터베이스 설정

#### PostgreSQL 환경 변수:
```bash
# 프로덕션 데이터베이스 연결
export DATABASE_URL="postgresql://username:password@host:5432/bowwow_production"

# 또는 개별 설정
export DATABASE_HOST="your-postgres-host.com"
export DATABASE_PORT="5432"
export DATABASE_USERNAME="bowwow_user"
export DATABASE_PASSWORD="secure_production_password"
export DATABASE_NAME="bowwow_production"
```

#### PostGIS 확장 (선택사항):
```sql
-- 고성능 공간 쿼리를 위한 PostGIS 설치
CREATE EXTENSION IF NOT EXISTS postgis;

-- 공간 인덱스 생성 (성능 향상)
CREATE INDEX idx_user_location_geom 
ON user_locations 
USING GIST (ST_Point(longitude, latitude));
```

### 3. Redis 캐싱 설정

#### Redis 환경 변수:
```bash
export REDIS_URL="redis://localhost:6379"
# 또는 클라우드 Redis
export REDIS_URL="redis://username:password@redis-host:6379"
```

### 4. 위치 데이터 암호화

#### 암호화 키 설정:
```bash
# AES-GCM 256비트 암호화 키 (32바이트, Base64 인코딩)
export LOCATION_ENCRYPTION_KEY="base64_encoded_32_byte_key_here"

# 보안 키 생성 예시 (Python)
# python3 -c "import os, base64; print(base64.b64encode(os.urandom(32)).decode())"
```

### 5. 서비스 URL 설정

#### 마이크로서비스 간 통신:
```bash
export USER_SERVICE_URL="http://user-service:8001"
export LOCATION_SERVICE_URL="http://location-service:8002"
export SIGNAL_SERVICE_URL="http://signal-service:8003"
export PUSH_SERVICE_URL="http://push-service:8004"
export ANALYTICS_SERVICE_URL="http://analytics-service:8005"
```

### 6. 로그 레벨 설정

#### 프로덕션 로깅:
```bash
export LOG_LEVEL="info"  # debug, info, notice, warning, error
```

## 🛡️ 보안 고려사항

### 1. 환경 변수 보안
- 모든 비밀 정보는 환경 변수로 관리
- `.env` 파일을 절대 Git에 커밋하지 않음
- Kubernetes Secrets 또는 AWS Parameter Store 사용 권장

### 2. HTTPS 강제 사용
```swift
// configure.swift에서 HTTPS 리다이렉트 설정
if app.environment == .production {
    app.middleware.use(HTTPSRedirectMiddleware())
}
```

### 3. CORS 설정
```swift
// 프로덕션에서는 특정 도메인만 허용
let corsConfiguration = CORSMiddleware.Configuration(
    allowedOrigin: .custom("https://yourapp.com"),
    allowedMethods: [.GET, .POST, .PUT, .DELETE],
    allowedHeaders: [.accept, .authorization, .contentType]
)
```

## 📊 모니터링 설정

### 1. 헬스 체크 엔드포인트
각 서비스는 `/health` 엔드포인트를 제공합니다:
- Gateway: http://localhost:8000/health
- UserService: http://localhost:8001/health
- LocationService: http://localhost:8002/health
- SignalService: http://localhost:8003/health
- PushService: http://localhost:8004/health
- AnalyticsService: http://localhost:8005/health

### 2. 메트릭 수집
Analytics Service에서 제공하는 엔드포인트:
- `/analytics/stats` - 시스템 전체 통계
- `/analytics/signals/activity` - 신호 활동 분석
- `/analytics/users/activity` - 사용자 활동 분석

## 🚀 배포 순서

### 1. 인프라 준비
1. PostgreSQL 데이터베이스 설정
2. Redis 인스턴스 설정
3. 로드 밸런서 구성

### 2. 서비스 배포
1. UserService 배포 및 마이그레이션 실행
2. LocationService 배포
3. SignalService 배포
4. PushService 배포 (APNS 설정 완료 후)
5. AnalyticsService 배포
6. Gateway 배포 (마지막)

### 3. 검증 절차
1. 각 서비스 헬스 체크 확인
2. 사용자 등록 API 테스트
3. 위치 업데이트 API 테스트
4. 신호 전송 API 테스트
5. 푸시 알림 기능 테스트

## 🎯 성능 최적화

### 1. 데이터베이스 최적화
```sql
-- 인덱스 생성
CREATE INDEX idx_user_locations_user_id ON user_locations(user_id);
CREATE INDEX idx_user_locations_created_at ON user_locations(created_at);
CREATE INDEX idx_signals_sender_id ON signals(sender_id);
CREATE INDEX idx_signals_sent_at ON signals(sent_at);
```

### 2. Redis 캐싱 전략
- 사용자 세션 캐싱
- 주변 사용자 쿼리 결과 캐싱 (30초 TTL)
- 신호 전파 상태 캐싱

### 3. Connection Pool 설정
```swift
// configure.swift
app.databases.use(.postgres(
    hostname: hostname,
    port: port,
    username: username,
    password: password,
    database: database,
    tlsConfiguration: .prefer(try .init(configuration: .clientDefault))
), as: .psql, maxConnectionsPerEventLoop: 4)
```

## 📱 iOS 클라이언트 연동

### 1. 디바이스 토큰 형식
- 128자 16진수 문자열
- 강타입 검증으로 잘못된 토큰 자동 차단

### 2. API 사용 예시
```swift
// 사용자 등록
POST /api/v1/users/register
{
  "deviceToken": "128_character_hex_string",
  "settings": {
    "isOffline": false,
    "distanceUnit": "km"
  }
}

// 위치 업데이트
POST /api/v1/locations/update
{
  "userID": "uuid",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "timestamp": "2025-08-31T23:00:00Z"
  }
}

// 신호 전송
POST /api/v1/signals
{
  "senderID": "uuid",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "timestamp": "2025-08-31T23:00:00Z"
  },
  "maxDistance": 5.0
}
```

---

**주의사항**: 이 가이드는 BowWow 시스템의 프로덕션 배포를 위한 기본 설정입니다. 실제 운영환경에서는 추가적인 보안 검토와 성능 테스트가 필요합니다.