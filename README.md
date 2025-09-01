# BowWow - Location-based Signal Service

A Swift microservices architecture built with Vapor, featuring real-time location streaming and signal propagation.

## Architecture

- **Gateway**: API gateway and request routing (Port 8000)
- **UserService**: User management and authentication (Port 8001) 
- **LocationService**: Real-time location tracking with WebSocket (Port 8002)
- **SignalService**: Signal propagation system (Port 8003)
- **PushService**: APNS push notifications (Port 8004)
- **AnalyticsService**: System metrics and analytics (Port 8005)

## Features

- 🏗️ **Type Driven Development** with strong types for compile-time safety
- 🔄 **Real-time WebSocket** location streaming
- 🔐 **AES-GCM encryption** for location data
- ⚡ **Signal propagation** at 1 mile/second over 10 miles
- 📱 **APNS integration** for push notifications
- 🧪 **Swift Testing** framework for unit tests

## Deployment

Ready for deployment on Railway, AWS, or other container platforms.

See `RAILWAY-DEPLOYMENT.md` for detailed deployment instructions.

## Local Development

```bash
# Install dependencies
swift package resolve

# Run all services
./run-all-services.sh

# Or run individually
swift run Gateway serve --port 8000
swift run UserService serve --port 8001
# ... etc
```

