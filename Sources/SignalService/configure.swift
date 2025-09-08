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
    app.migrations.add(CreateSignal())
    app.migrations.add(CreateSignalReceipt())
    
    // TODO: [REDIS-001] Redis 연결 설정 및 신호 캐싱 구현 필요
    // TODO: [REDIS-002] 신호 전파 상태를 Redis에 캐싱하여 성능 최적화
    // TODO: [REDIS-003] 실시간 신호 브로드캐스트를 위한 Redis Pub/Sub 구현
    // TODO: [REDIS-004] 신호 중복 처리 방지를 위한 Redis 기반 동시성 제어
    /*
    예시 Redis 설정:
    if let redisURL = Environment.get("REDIS_URL") {
        try app.redis.configure(url: redisURL)
        
        // 신호 상태 캐싱 설정
        app.redis.configuration.pool.connectionRetryTimeout = .seconds(10)
        app.logger.info("✅ Redis connected for signal caching: \(redisURL)")
        
        // 실시간 브로드캐스트를 위한 Pub/Sub 설정
        // await app.redis.publish("signal:broadcast", to: "signal_channel")
    }
    */
    
    // MARK: - HTTP Client Configuration
    app.http.client.configuration.timeout = HTTPClient.Configuration.Timeout(
        connect: .seconds(5),
        read: .seconds(30)
    )
    
    app.logger.info("✅ Signal Service configuration completed")
}