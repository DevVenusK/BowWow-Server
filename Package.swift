// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BowWow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Gateway", targets: ["Gateway"]),
        .executable(name: "UserService", targets: ["UserService"]),
        .executable(name: "LocationService", targets: ["LocationService"]),
        .executable(name: "SignalService", targets: ["SignalService"]),
        .executable(name: "PushService", targets: ["PushService"]),
        .executable(name: "AnalyticsService", targets: ["AnalyticsService"]),
        .library(name: "Shared", targets: ["Shared"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.7.2"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/apns.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0")
    ],
    targets: [
        // MARK: - Shared Library
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Redis", package: "redis"),
                .product(name: "VaporAPNS", package: "apns"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        
        // MARK: - Gateway Service
        .executableTarget(
            name: "Gateway",
            dependencies: [
                "Shared",
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        
        // MARK: - User Service
        .executableTarget(
            name: "UserService",
            dependencies: [
                "Shared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
            ]
        ),
        
        // MARK: - Location Service
        .executableTarget(
            name: "LocationService", 
            dependencies: [
                "Shared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Redis", package: "redis")
            ]
        ),
        
        // MARK: - Signal Service
        .executableTarget(
            name: "SignalService",
            dependencies: [
                "Shared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        
        // MARK: - Push Service
        .executableTarget(
            name: "PushService",
            dependencies: [
                "Shared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporAPNS", package: "apns"),
                .product(name: "Redis", package: "redis")
            ]
        ),
        
        // MARK: - Analytics Service
        .executableTarget(
            name: "AnalyticsService",
            dependencies: [
                "Shared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Redis", package: "redis")
            ]
        ),
        
        // MARK: - Tests (Swift Testing) - Excluded from production build
    ]
)