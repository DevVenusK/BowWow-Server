# Multi-stage build for BowWow services
FROM swift:5.9-jammy as build

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    zlib1g-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy Package files (excluding Tests)
COPY Package.swift Package.resolved ./
COPY Sources ./Sources

# Build the project
RUN swift build -c release

# Production stage
FROM swift:5.9-jammy-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    libpq5 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Set working directory and copy built executables
WORKDIR /app
COPY --from=build --chown=vapor:vapor /build/.build/release/Gateway ./Gateway
COPY --from=build --chown=vapor:vapor /build/.build/release/UserService ./UserService  
COPY --from=build --chown=vapor:vapor /build/.build/release/LocationService ./LocationService
COPY --from=build --chown=vapor:vapor /build/.build/release/SignalService ./SignalService
COPY --from=build --chown=vapor:vapor /build/.build/release/PushService ./PushService
COPY --from=build --chown=vapor:vapor /build/.build/release/AnalyticsService ./AnalyticsService

# Copy startup script
COPY --chown=vapor:vapor start-services.sh ./start-services.sh
RUN chmod +x ./start-services.sh

# Switch to vapor user
USER vapor:vapor

# Start all services using the startup script
CMD ["./start-services.sh"]