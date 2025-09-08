import Vapor
import VaporAPNS
import Shared

public func configure(_ app: Application) throws {
    
    // MARK: - Middleware Configuration
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )))
    
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // MARK: - APNS Configuration
    if app.environment != .testing {
        // Production/Development APNS 설정
        if let keyID = Environment.get("APNS_KEY_ID"),
           let teamID = Environment.get("APNS_TEAM_ID"),
           let keyPath = Environment.get("APNS_KEY_PATH") {
            
            // TODO: [APNS-001] 실제 VaporAPNS 라이브러리 초기화 구현 필요
            // TODO: [APNS-002] APNS 인증키 파일(.p8) 업로드 및 경로 검증 추가
            // TODO: [APNS-003] 실제 푸시 알림 전송 로직 구현 (현재는 설정 저장만)
            // VaporAPNS 설정을 위한 정보 저장 (실제 구현 시 사용)
            app.storage[APNSConfigKey.self] = APNSConfig(
                keyID: keyID,
                teamID: teamID,
                keyPath: keyPath,
                topic: Environment.get("APNS_TOPIC") ?? "com.bowwow.app",
                environment: app.environment == .production ? .production : .sandbox
            )
            app.logger.info("✅ APNS configured with JWT authentication")
            app.logger.info("   Key ID: \(keyID)")
            app.logger.info("   Team ID: \(teamID)")
            app.logger.info("   Environment: \(app.environment == .production ? "Production" : "Sandbox")")
        } else {
            app.logger.warning("⚠️  APNS configuration missing - Required:")
            app.logger.warning("   APNS_KEY_ID: Apple 개발자 계정에서 생성한 키 ID")
            app.logger.warning("   APNS_TEAM_ID: Apple 개발자 팀 ID")  
            app.logger.warning("   APNS_KEY_PATH: AuthKey_XXXXX.p8 파일 경로")
            app.logger.warning("   APNS_TOPIC: 번들 식별자 (예: com.bowwow.app)")
        }
    }
    
    // MARK: - HTTP Client Configuration
    app.http.client.configuration.timeout = HTTPClient.Configuration.Timeout(
        connect: .seconds(5),
        read: .seconds(30)
    )
    
    app.logger.info("✅ Push Service configuration completed")
}

// MARK: - APNS Configuration Storage

struct APNSConfigKey: StorageKey {
    typealias Value = APNSConfig
}

struct APNSConfig {
    let keyID: String
    let teamID: String
    let keyPath: String
    let topic: String
    let environment: APNSEnvironment
}

enum APNSEnvironment: String {
    case production = "production"
    case sandbox = "sandbox"
}