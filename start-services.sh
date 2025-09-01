#!/bin/bash

# BowWow Multi-Service Startup Script

echo "🚀 Starting BowWow Services..."

# Export environment variables for consistent port configuration
export USER_SERVICE_PORT=8001
export LOCATION_SERVICE_PORT=8002  
export SIGNAL_SERVICE_PORT=8003
export PUSH_SERVICE_PORT=8004
export ANALYTICS_SERVICE_PORT=8005
export GATEWAY_PORT=${PORT:-8000}

# Start all services in background (no command-line arguments needed)
echo "📊 Starting AnalyticsService..."
./AnalyticsService &
ANALYTICS_PID=$!

echo "📍 Starting LocationService..."  
./LocationService &
LOCATION_PID=$!

echo "📧 Starting PushService..."
./PushService &
PUSH_PID=$!

echo "📡 Starting SignalService..."
./SignalService &
SIGNAL_PID=$!

echo "👤 Starting UserService..."
./UserService &
USER_PID=$!

# Wait a moment for services to start
sleep 5

echo "🌐 Starting Gateway..."
./Gateway &
GATEWAY_PID=$!

echo "✅ All services started!"
echo "Service PIDs: Analytics=$ANALYTICS_PID, Location=$LOCATION_PID, Push=$PUSH_PID, Signal=$SIGNAL_PID, User=$USER_PID, Gateway=$GATEWAY_PID"

# Function to handle shutdown
cleanup() {
    echo "🛑 Shutting down all services..."
    kill $ANALYTICS_PID $LOCATION_PID $PUSH_PID $SIGNAL_PID $USER_PID $GATEWAY_PID 2>/dev/null
    wait $ANALYTICS_PID $LOCATION_PID $PUSH_PID $SIGNAL_PID $USER_PID $GATEWAY_PID 2>/dev/null
    echo "👋 All services stopped."
    exit 0
}

# Setup signal handlers
trap cleanup SIGTERM SIGINT

# Wait for all background processes
wait