-- BowWow PostGIS Spatial Indexes and Functions Setup
-- This script should be run after Fluent migrations are applied

-- TODO: [POSTGIS-001] 공간 인덱스 생성 (user_locations 테이블)
-- Create spatial index for user_locations table for efficient proximity queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_locations_point 
  ON user_locations USING GIST (ST_Point(longitude, latitude));

-- TODO: [POSTGIS-002] 공간 인덱스 생성 (signals 테이블)  
-- Create spatial index for signals table for efficient signal range queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signals_point
  ON signals USING GIST (ST_Point(longitude, latitude));

-- TODO: [POSTGIS-003] 복합 인덱스 생성 (만료 시간 + 공간)
-- Create composite index for efficient expired location cleanup
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_locations_expires_point
  ON user_locations USING GIST (expires_at, ST_Point(longitude, latitude));

-- TODO: [POSTGIS-004] 사용자 주변 검색 함수 구현
-- Function to find users within a specified radius (meters)
CREATE OR REPLACE FUNCTION find_users_within_radius(
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION, 
  radius_meters INTEGER
)
RETURNS TABLE(user_id UUID, distance_meters DOUBLE PRECISION) AS $$
BEGIN
  RETURN QUERY
  SELECT ul.user_id, 
         ST_Distance(
           ST_Point(center_lng, center_lat)::geography,
           ST_Point(ul.longitude, ul.latitude)::geography
         ) as distance_meters
  FROM user_locations ul
  WHERE ul.expires_at > NOW()  -- 만료되지 않은 위치만
    AND ST_DWithin(
          ST_Point(center_lng, center_lat)::geography,
          ST_Point(ul.longitude, ul.latitude)::geography,
          radius_meters
        )
  ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;

-- TODO: [POSTGIS-005] 신호 범위 내 사용자 검색 함수
-- Function to find users within signal range
CREATE OR REPLACE FUNCTION find_users_in_signal_range(
  signal_id UUID
)
RETURNS TABLE(
  user_id UUID, 
  distance_meters DOUBLE PRECISION,
  signal_lat DOUBLE PRECISION,
  signal_lng DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT ul.user_id,
         ST_Distance(
           ST_Point(s.longitude, s.latitude)::geography,
           ST_Point(ul.longitude, ul.latitude)::geography
         ) as distance_meters,
         s.latitude as signal_lat,
         s.longitude as signal_lng
  FROM signals s
  JOIN user_locations ul ON (
    ul.expires_at > NOW()
    AND ul.user_id != s.sender_id  -- 신호 발송자 제외
    AND ST_DWithin(
          ST_Point(s.longitude, s.latitude)::geography,
          ST_Point(ul.longitude, ul.latitude)::geography,
          s.max_distance * 1000  -- km to meters
        )
  )
  WHERE s.id = signal_id
    AND s.expires_at > NOW()
    AND s.status = 'active'
  ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;

-- TODO: [POSTGIS-006] 만료된 위치 데이터 정리 함수
-- Function to clean up expired location data efficiently using spatial index
CREATE OR REPLACE FUNCTION cleanup_expired_locations()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM user_locations 
  WHERE expires_at <= NOW();
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  -- 통계 테이블에 정리 로그 기록 (선택사항)
  -- INSERT INTO cleanup_logs (table_name, deleted_count, cleanup_at)
  -- VALUES ('user_locations', deleted_count, NOW());
  
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- TODO: [POSTGIS-007] 성능 최적화를 위한 추가 인덱스들
-- Additional performance indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_locations_user_expires 
  ON user_locations (user_id, expires_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signals_sender_status_expires
  ON signals (sender_id, status, expires_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signal_receipts_signal_receiver
  ON signal_receipts (signal_id, receiver_id, received_at);

-- TODO: [POSTGIS-008] 공간 데이터 분석 뷰 생성
-- Analytical views for spatial data insights
CREATE OR REPLACE VIEW active_user_locations AS
SELECT 
  ul.user_id,
  ul.latitude,
  ul.longitude,
  ul.created_at,
  ul.expires_at,
  EXTRACT(EPOCH FROM (ul.expires_at - NOW())) / 3600 as hours_until_expire
FROM user_locations ul
WHERE ul.expires_at > NOW();

CREATE OR REPLACE VIEW active_signals_with_range AS  
SELECT 
  s.id as signal_id,
  s.sender_id,
  s.latitude,
  s.longitude, 
  s.max_distance,
  s.status,
  s.sent_at,
  s.expires_at,
  EXTRACT(EPOCH FROM (s.expires_at - NOW())) / 60 as minutes_until_expire
FROM signals s
WHERE s.expires_at > NOW() 
  AND s.status = 'active';

-- TODO: [POSTGIS-009] 정기 정리 작업을 위한 함수들
-- Maintenance functions for regular cleanup
CREATE OR REPLACE FUNCTION vacuum_spatial_tables()
RETURNS VOID AS $$
BEGIN
  -- 공간 인덱스 성능 유지를 위한 정기 VACUUM
  VACUUM ANALYZE user_locations;
  VACUUM ANALYZE signals;
  VACUUM ANALYZE signal_receipts;
  
  -- 공간 인덱스 통계 업데이트
  REINDEX INDEX CONCURRENTLY idx_user_locations_point;
  REINDEX INDEX CONCURRENTLY idx_signals_point;
END;
$$ LANGUAGE plpgsql;

SELECT 'PostGIS 공간 인덱스 및 함수 설정 완료!' as status;