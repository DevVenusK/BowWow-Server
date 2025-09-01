# 🚂 BowWow Railway 배포 가이드

## 📋 배포 전 체크리스트

### ✅ 준비 완료된 항목
- [x] Docker 설정 (Dockerfile, .dockerignore)
- [x] Railway CLI 설치
- [x] Railway 설정 파일 (railway.toml)

### 📝 배포 단계

## 1단계: Railway 로그인 및 프로젝트 생성

```bash
# Railway 로그인 (웹 브라우저에서 GitHub 연동)
railway login

# 새 프로젝트 생성
railway init bowwow

# 현재 디렉토리와 연결
railway link
```

## 2단계: 데이터베이스 생성

### PostgreSQL 데이터베이스 추가
```bash
# PostgreSQL 서비스 추가
railway add --database postgresql

# Redis 서비스 추가
railway add --database redis
```

또는 Railway 대시보드에서:
1. 프로젝트 대시보드 접속
2. "New Service" 클릭
3. "Database" → "PostgreSQL" 선택
4. "New Service" 클릭
5. "Database" → "Redis" 선택

## 3단계: 환경 변수 설정

각 서비스별로 환경 변수를 설정해야 합니다:

### 공통 환경 변수
```bash
# 데이터베이스 URL (Railway에서 자동 생성)
DATABASE_URL=${{Postgres.DATABASE_URL}}

# Redis URL (Railway에서 자동 생성)  
REDIS_URL=${{Redis.REDIS_URL}}

# 프로덕션 환경
VAPOR_ENV=production
LOG_LEVEL=info
```

### Gateway 서비스 환경 변수
```bash
# 서비스 간 통신 URL (Railway 내부 네트워크)
USER_SERVICE_URL=${{UserService.RAILWAY_PRIVATE_DOMAIN}}
LOCATION_SERVICE_URL=${{LocationService.RAILWAY_PRIVATE_DOMAIN}}
SIGNAL_SERVICE_URL=${{SignalService.RAILWAY_PRIVATE_DOMAIN}}
PUSH_SERVICE_URL=${{PushService.RAILWAY_PRIVATE_DOMAIN}}
ANALYTICS_SERVICE_URL=${{AnalyticsService.RAILWAY_PRIVATE_DOMAIN}}

# 실행 명령어
RAILWAY_RUN_COMMAND=./Gateway serve --env production --hostname 0.0.0.0 --port $PORT
```

### 각 마이크로서비스 환경 변수
```bash
# UserService
RAILWAY_RUN_COMMAND=./UserService serve --env production --hostname 0.0.0.0 --port $PORT

# LocationService  
RAILWAY_RUN_COMMAND=./LocationService serve --env production --hostname 0.0.0.0 --port $PORT
LOCATION_ENCRYPTION_KEY=your-base64-encryption-key-here

# SignalService
RAILWAY_RUN_COMMAND=./SignalService serve --env production --hostname 0.0.0.0 --port $PORT

# PushService (APNS 설정 필요)
RAILWAY_RUN_COMMAND=./PushService serve --env production --hostname 0.0.0.0 --port $PORT
APNS_KEY_ID=your-apns-key-id
APNS_TEAM_ID=your-apns-team-id  
APNS_KEY_PATH=your-apns-key-path
APNS_TOPIC=com.yourcompany.bowwow

# AnalyticsService
RAILWAY_RUN_COMMAND=./AnalyticsService serve --env production --hostname 0.0.0.0 --port $PORT
```

## 4단계: 서비스별 배포

Railway는 모노레포에서 여러 서비스를 배포할 수 있습니다:

### 방법 1: CLI를 통한 배포
```bash
# 각 서비스를 개별적으로 배포
railway service create gateway
railway service create user-service
railway service create location-service
railway service create signal-service
railway service create push-service
railway service create analytics-service

# 각 서비스별로 환경 변수와 실행 명령어 설정 후
railway up
```

### 방법 2: 대시보드를 통한 배포
1. Railway 프로젝트 대시보드 접속
2. "New Service" → "GitHub Repo" 선택
3. BowWow 저장소 연결
4. 각 서비스별로 별도의 서비스 생성
5. 각 서비스의 Settings에서 환경 변수 및 실행 명령어 설정

## 5단계: 도메인 설정

### 커스텀 도메인 연결 (선택사항)
```bash
# 도메인 추가
railway domain add yourdomain.com

# 또는 Railway 기본 도메인 사용
# gateway-production-xxx.up.railway.app
```

## 6단계: 배포 확인

### 헬스 체크 확인
```bash
# 각 서비스 헬스 체크
curl https://gateway-production-xxx.up.railway.app/health
curl https://user-service-production-xxx.up.railway.app/health
curl https://location-service-production-xxx.up.railway.app/health
curl https://signal-service-production-xxx.up.railway.app/health
curl https://push-service-production-xxx.up.railway.app/health
curl https://analytics-service-production-xxx.up.railway.app/health
```

### 로그 확인
```bash
# 실시간 로그 보기
railway logs --service gateway
railway logs --service user-service
# ... 각 서비스별
```

## 7단계: 데이터베이스 마이그레이션

각 서비스가 배포된 후 데이터베이스 마이그레이션을 실행:

```bash
# Railway CLI를 통한 명령어 실행
railway shell --service user-service
# 컨테이너 내에서: swift run UserService migrate

# 또는 Railway 대시보드에서 서비스 → Variables → RAILWAY_RUN_COMMAND 임시 변경:
# ./UserService migrate --env production
```

## 📊 Railway 리소스 사용량 모니터링

### 무료 플랜 제한사항
- $5 크레딧/월
- 메모리: 512MB per 서비스
- CPU: 0.5 vCPU per 서비스  
- 네트워크: 100GB/월

### 비용 최적화 팁
1. **서비스 통합**: 트래픽이 적을 때는 일부 서비스 통합 고려
2. **슬립 모드**: 비활성 시 자동 슬립 (Railway 기본 기능)
3. **리소스 모니터링**: Railway 대시보드에서 실시간 모니터링

## 🚀 배포 자동화 (GitHub Actions)

Railway는 GitHub와 자동 연동됩니다:

```yaml
# .github/workflows/railway.yml
name: Deploy to Railway

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to Railway
      uses: railway/cli@v3
      with:
        token: ${{ secrets.RAILWAY_TOKEN }}
      env:
        RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
      run: railway up
```

## 🔧 트러블슈팅

### 일반적인 문제들

#### 1. 빌드 실패
```bash
# 로그 확인
railway logs --service gateway

# 일반적 원인: 메모리 부족
# 해결: Dockerfile 최적화 또는 플랜 업그레이드
```

#### 2. 서비스 간 통신 실패
```bash
# 환경 변수 확인
railway variables --service gateway

# Railway 내부 도메인 사용 확인
# 예: user-service.railway.internal:8001
```

#### 3. 데이터베이스 연결 실패
```bash
# DATABASE_URL 확인
railway variables --service user-service

# PostgreSQL 서비스 상태 확인
railway status --service postgresql
```

## 🎯 다음 단계

배포 완료 후:
1. ✅ API 엔드포인트 테스트
2. ✅ WebSocket 연결 테스트  
3. ✅ 실제 iOS 앱에서 연동 테스트
4. ✅ 성능 모니터링 설정
5. ✅ 에러 알림 설정

## 📞 도움이 필요할 때

- Railway 문서: https://docs.railway.app
- Railway Discord: https://discord.gg/railway  
- Swift on Railway 예제: https://github.com/railwayapp/examples

---

이 가이드를 따라하시면 BowWow 시스템을 Railway에 성공적으로 배포할 수 있습니다! 🎉