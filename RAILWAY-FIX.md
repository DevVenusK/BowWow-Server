# Railway Deployment 문제 해결

## 문제
Railway가 Railpack을 사용하여 빌드하려고 하지만, Swift 프로젝트를 인식하지 못함

## 해결책

### 방법 1: 새 프로젝트 생성 (권장)
1. 현재 Railway 프로젝트 삭제
2. 새 프로젝트 생성시 **"Empty Project"** 선택
3. **"Add service from GitHub repo"** 선택
4. 저장소 연결 후 **Settings** → **Source** 에서:
   - Build Command: `echo "Using Dockerfile"`
   - Start Command: `./Gateway serve --env production --hostname 0.0.0.0 --port $PORT`

### 방법 2: 현재 프로젝트 수정
Railway 대시보드 → Settings → Build에서:
1. **Source** 섹션:
   - "Override build command" 체크
   - Build Command: (비우기)
2. **Docker** 섹션:
   - "Use Dockerfile" 체크
   - Dockerfile Path: `Dockerfile`

### 방법 3: Railway CLI 사용 (브라우저에서)
```bash
# 브라우저에서 Railway 사이트 접속 후
railway login
railway link
railway up --detach
```

## 환경변수 설정 필수
```
VAPOR_ENV=production
DATABASE_URL=${Postgres.DATABASE_URL}
REDIS_URL=${Redis.REDIS_URL}
```