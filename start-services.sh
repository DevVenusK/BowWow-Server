#!/bin/bash

# BowWow Multi-Service Startup Script

echo "🚀 Starting BowWow Services..."

# Start all services in background
echo "📊 Starting AnalyticsService on port 8005..."
./AnalyticsService serve --env production --hostname 0.0.0.0 --port 8005 &
ANALYTICS_PID=$!

echo "📍 Starting LocationService on port 8002..."  
./LocationService serve --env production --hostname 0.0.0.0 --port 8002 &
LOCATION_PID=$!

echo "📧 Starting PushService on port 8004..."
./PushService serve --env production --hostname 0.0.0.0 --port 8004 &
PUSH_PID=$!

echo "📡 Starting SignalService on port 8003..."
./SignalService serve --env production --hostname 0.0.0.0 --port 8003 &
SIGNAL_PID=$!

echo "👤 Starting UserService on port 8001..."
./UserService serve --env production --hostname 0.0.0.0 --port 8001 &
USER_PID=$!

# Wait a moment for services to start
sleep 5

echo "🌐 Starting Gateway on port ${PORT:-8000}..."
./Gateway serve --env production --hostname 0.0.0.0 --port ${PORT:-8000} &
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