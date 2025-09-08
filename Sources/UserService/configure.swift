import Vapor
import Fluent
import FluentPostgresDriver
import Shared

public func configure(_ app: Application) throws {
    
    // MARK: - Middleware Configuration
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )))
    
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // MARK: - Database Configuration
    if let databaseURL = Environment.get("DATABASE_URL") {
        try app.databases.use(.postgres(url: databaseURL), as: .psql)
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
    
    // TODO: [REDIS-001] Redis 캐시 설정 및 연결 구현 필요
    // TODO: [REDIS-002] REDIS_URL 환경 변수 처리 및 연결 풀 설정
    // TODO: [REDIS-003] 사용자 정보 캐싱 로직 구현 (세션, 프로필)
    // TODO: [REDIS-004] Device Token 캐싱으로 성능 최적화
    /*
    예시 Redis 설정:
    if let redisURL = Environment.get("REDIS_URL") {
        try app.redis.configure(url: redisURL)
        app.logger.info("✅ Redis connected: \(redisURL)")
    }
    */
    
    // MARK: - HTTP Client Configuration
    app.http.client.configuration.timeout = HTTPClient.Configuration.Timeout(
        connect: .seconds(5),
        read: .seconds(30)
    )
    
    app.logger.info("✅ User Service configuration completed")
}