#!/bin/bash

# BowWow Database Setup Script
# This script sets up PostgreSQL with PostGIS extension for BowWow services

set -e

echo "🐕 Setting up BowWow Database with PostGIS..."

# TODO: [POSTGIS-005] Database configuration variables
DB_HOST="${DATABASE_HOST:-localhost}"
DB_PORT="${DATABASE_PORT:-5432}"
DB_USER="${DATABASE_USERNAME:-postgres}"
DB_PASSWORD="${DATABASE_PASSWORD:-password}"
DB_NAME="${DATABASE_NAME:-bowwow}"

echo "📊 Database Configuration:"
echo "   Host: $DB_HOST"
echo "   Port: $DB_PORT"
echo "   User: $DB_USER"
echo "   Database: $DB_NAME"

# TODO: [POSTGIS-006] Create database if it doesn't exist
echo "📝 Creating database '$DB_NAME' if it doesn't exist..."
PGPASSWORD="$DB_PASSWORD" createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" || echo "Database already exists or creation failed"

# TODO: [POSTGIS-007] Enable PostGIS extension
echo "🗺️  Enabling PostGIS extension..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- TODO: [POSTGIS-008] Create spatial indexes for user_locations table
-- This will be applied after Fluent migrations create the tables
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_locations_point 
--   ON user_locations USING GIST (ST_Point(longitude, latitude));

-- TODO: [POSTGIS-009] Add spatial functions for distance calculations
-- Example function to find users within radius:
-- CREATE OR REPLACE FUNCTION find_users_within_radius(
--   center_lat DOUBLE PRECISION,
--   center_lng DOUBLE PRECISION, 
--   radius_meters INTEGER
-- )
-- RETURNS TABLE(user_id UUID, distance_meters DOUBLE PRECISION) AS \$\$
-- BEGIN
--   RETURN QUERY
--   SELECT ul.user_id, 
--          ST_Distance(
--            ST_Point(center_lng, center_lat)::geography,
--            ST_Point(ul.longitude, ul.latitude)::geography
--          ) as distance_meters
--   FROM user_locations ul
--   WHERE ST_DWithin(
--           ST_Point(center_lng, center_lat)::geography,
--           ST_Point(ul.longitude, ul.latitude)::geography,
--           radius_meters
--         )
--   ORDER BY distance_meters;
-- END;
-- \$\$ LANGUAGE plpgsql;

SELECT 'PostGIS setup completed successfully!' as status;
EOF

echo "✅ Database setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Run: swift run Gateway migrate"
echo "   2. Apply spatial indexes after migration"
echo "   3. Test PostGIS functions"