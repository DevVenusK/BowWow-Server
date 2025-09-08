import Vapor
import Fluent
import FluentPostgresDriver
import PostgresNIO
import Shared

public func configure(_ app: Application) throws {
    
    // MARK: - Middleware Configuration
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )))
    
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // TODO: [AUTH-001] JWT 인증 미들웨어 추가 필요
    // TODO: [AUTH-002] API Key 기반 서비스 간 인증 구현 필요
    // TODO: [AUTH-003] Rate limiting 미들웨어 추가 필요
    // TODO: [AUTH-004] JWT_SECRET 환경 변수 설정 및 검증 추가
    /*
    예시 JWT 미들웨어 구현:
    if let jwtSecret = Environment.get("JWT_SECRET") {
        app.jwt.signers.use(.hs256(key: jwtSecret))
        let protected = app.grouped(JWTBearerAuthenticator())
        // 보호된 라우트에 사용
    }
    */
    
    // MARK: - Database Configuration
    if let databaseURL = Environment.get("DATABASE_URL") {
        // Railway PostgreSQL - use URL configuration with TLS disabled for Railway compatibility
        var config = try SQLPostgresConfiguration(url: databaseURL)
        config.coreConfiguration.tls = .disable  // Disable TLS verification for Railway
        
        app.databases.use(.postgres(configuration: config), as: .psql)
    } else {
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
            username: Environment.get("DATABASE_USERNAME") ?? "postgres",
            password: Environment.get("DATABASE_PASSWORD") ?? "password",
            database: Environment.get("DATABASE_NAME") ?? "bowwow"
        ), as: .psql)
    }
    
    // MARK: - Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserLocation())
    app.migrations.add(CreateSignal())
    app.migrations.add(CreateSignalReceipt())
    
    // MARK: - HTTP Client Configuration
    app.http.client.configuration.timeout = HTTPClient.Configuration.Timeout(
        connect: .seconds(5),
        read: .seconds(30)
    )
    
    // MARK: - Service URLs Configuration
    app.storage[ServiceURLsKey.self] = ServiceURLs(
        userService: Environment.get("USER_SERVICE_URL") ?? "http://localhost:8001",
        locationService: Environment.get("LOCATION_SERVICE_URL") ?? "http://localhost:8002",
        signalService: Environment.get("SIGNAL_SERVICE_URL") ?? "http://localhost:8003",
        pushService: Environment.get("PUSH_SERVICE_URL") ?? "http://localhost:8004",
        analyticsService: Environment.get("ANALYTICS_SERVICE_URL") ?? "http://localhost:8005"
    )
    
    app.logger.info("✅ Gateway configuration completed")
}

// MARK: - Service URLs Storage

struct ServiceURLsKey: StorageKey {
    typealias Value = ServiceURLs
}

public struct ServiceURLs {
    let userService: String
    let locationService: String
    let signalService: String
    let pushService: String
    let analyticsService: String
}