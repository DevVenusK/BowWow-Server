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
    app.migrations.add(CreateUserLocation())
    
    // TODO: [CRYPTO-001] 프로덕션 환경용 안전한 암호화 키 관리 시스템 구현 필요
    // TODO: [CRYPTO-002] LOCATION_ENCRYPTION_KEY 환경 변수 설정 및 검증 추가
    // TODO: [CRYPTO-003] 키 순환(Key Rotation) 정책 구현 필요
    // TODO: [CRYPTO-004] AWS KMS, HashiCorp Vault 등 외부 키 관리 서비스 연동 고려
    /*
    예시 암호화 키 관리 구현:
    guard let encryptionKey = Environment.get("LOCATION_ENCRYPTION_KEY"),
          !encryptionKey.isEmpty else {
        app.logger.critical("❌ LOCATION_ENCRYPTION_KEY가 설정되지 않음")
        throw BowWowError.configurationError("Missing LOCATION_ENCRYPTION_KEY")
    }
    
    // 키 무결성 검증 (32바이트 Base64)
    guard let keyData = Data(base64Encoded: encryptionKey),
          keyData.count == 32 else {
        app.logger.critical("❌ 유효하지 않은 암호화 키 형식")
        throw BowWowError.configurationError("Invalid LOCATION_ENCRYPTION_KEY format")
    }
    
    app.logger.info("✅ 위치 데이터 암호화 키 설정 완료")
    */
    
    // MARK: - HTTP Client Configuration
    app.http.client.configuration.timeout = HTTPClient.Configuration.Timeout(
        connect: .seconds(5),
        read: .seconds(30)
    )
    
    // MARK: - WebSocket Configuration
    app.webSocket("locations", "stream") { req, ws in
        LocationStreamManager.shared.addConnection(ws: ws, req: req)
    }
    
    app.logger.info("✅ Location Service configuration completed")
}