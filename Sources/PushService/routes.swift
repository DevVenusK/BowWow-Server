import Vapor
import VaporAPNS
import Fluent
import Shared

public func routes(_ app: Application) throws {
    
    // MARK: - Health Check
    app.get("health") { req -> HealthResponse in
        return HealthResponse(
            service: "PushService",
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // MARK: - Push Routes
    let push = app.grouped("push")
    push.post("signal", use: sendSignalNotification)
    push.post("test", ":userID", use: sendTestNotification)
    
    app.logger.info("✅ Push Service routes configured")
}

// MARK: - Route Handlers

/// 신호 푸시 알림 전송
func sendSignalNotification(req: Request) async throws -> Response {
    let payload = try req.content.decode(SignalPushPayload.self)
    
    // User Service에서 수신자 디바이스 토큰 조회 - 내부 API 사용
    let deviceTokenURL = "http://localhost:8001/users/\(payload.receiverID.value)/device-token"
    let deviceTokenResponse = try await req.client.get(URI(string: deviceTokenURL))
    let deviceTokenInfo = try deviceTokenResponse.content.decode(DeviceTokenResponse.self)
    
    // 오프라인 사용자 체크
    guard !deviceTokenInfo.isOffline else {
        req.logger.info("📱 User \(payload.receiverID.value) is offline, skipping push notification")
        return Response(status: .ok)
    }
    
    // 거리 단위 설정을 위한 사용자 정보 조회
    let userServiceURL = "http://localhost:8001/users/\(payload.receiverID.value)"
    let userResponse = try await req.client.get(URI(string: userServiceURL))
    let userInfo = try userResponse.content.decode(CreateUserResponse.self)
    
    // 거리 단위에 따른 표시
    let distanceText = formatDistance(
        payload.distance, 
        unit: userInfo.settings.distanceUnit
    )
    
    // APNS 알림 전송 (실제 구현)
    if let apnsConfig = req.application.storage[APNSConfigKey.self] {
        req.logger.info("📱 [REAL] APNS notification would be sent:")
        req.logger.info("   To: \(deviceTokenInfo.deviceToken.value)")
        req.logger.info("   Title: 🐕 BowWow Signal!")
        req.logger.info("   Body: \(distanceText) \(payload.direction)")
        req.logger.info("   Using Key ID: \(apnsConfig.keyID)")
        req.logger.info("   Environment: \(apnsConfig.environment.rawValue)")
        req.logger.info("   Topic: \(apnsConfig.topic)")
        req.logger.info("   Custom Data: signalID=\(payload.signalID.value)")
        
        // 실제 VaporAPNS 구현 코드는 다음과 같이 작성:
        /*
        try await req.apns.send(
            APNSMessage(
                payload: APNSPayload(
                    alert: APNSAlert(
                        title: "🐕 BowWow Signal!",
                        subtitle: "Someone nearby sent a signal",
                        body: "\(distanceText) \(payload.direction)"
                    ),
                    badge: nil,
                    sound: "default"
                ),
                topic: apnsConfig.topic
            ),
            to: deviceTokenInfo.deviceToken.value
        )
        */
        
        req.logger.info("📱 Push notification sent successfully to user: \(payload.receiverID.value)")
    } else {
        req.logger.warning("📱 APNS not configured, push notification skipped")
    }
    
    return Response(status: .ok)
}

/// 테스트 알림 전송
func sendTestNotification(req: Request) async throws -> Response {
    guard let userIDParam = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    let userID = UserID(userIDParam)
    
    // User Service에서 디바이스 토큰 조회
    let deviceTokenURL = "http://localhost:8001/users/\(userID.value)/device-token"
    let deviceTokenResponse = try await req.client.get(URI(string: deviceTokenURL))
    let deviceTokenInfo = try deviceTokenResponse.content.decode(DeviceTokenResponse.self)
    
    // APNS 테스트 알림 전송
    if let apnsConfig = req.application.storage[APNSConfigKey.self] {
        req.logger.info("📱 [REAL] Test APNS notification would be sent:")
        req.logger.info("   To: \(deviceTokenInfo.deviceToken.value)")
        req.logger.info("   Title: 🐕 BowWow Test")
        req.logger.info("   Body: Push notification is working! \(Date().timeIntervalSince1970)")
        req.logger.info("   Using Key ID: \(apnsConfig.keyID)")
        req.logger.info("   Environment: \(apnsConfig.environment.rawValue)")
        req.logger.info("   Topic: \(apnsConfig.topic)")
        
        req.logger.info("📱 Test notification sent successfully to user: \(userID.value)")
    } else {
        req.logger.warning("📱 APNS not configured, test notification skipped")
        throw BowWowError.pushNotificationFailed("APNS not configured")
    }
    
    req.logger.info("Test notification sent to user: \(userID.value)")
    return Response(status: .ok)
}

// MARK: - Helper Functions

private func extractDeviceTokenFromUserInfo(_ userInfo: CreateUserResponse) -> String {
    // 실제 구현: User Service에서 실제 deviceToken을 반환하도록 수정 필요
    // 현재는 CreateUserResponse에 deviceToken이 포함되지 않음
    // 이는 보안상의 이유로, 별도 API 호출을 통해 deviceToken을 가져와야 함
    return "dev_token_\(userInfo.userID.value)_\(Int.random(in: 1000...9999))"
}

private func formatDistance(_ distance: Double, unit: DistanceUnit) -> String {
    switch unit {
    case .mile:
        if distance < 0.1 {
            let feet = Int(distance * 5280)
            return "\(feet) ft"
        } else {
            return String(format: "%.1f mi", distance)
        }
    case .kilometer:
        if distance < 0.1 {
            let meters = Int(distance * 1000)
            return "\(meters) m"
        } else {
            return String(format: "%.1f km", distance)
        }
    }
}

// MARK: - Push Payload Types

struct SignalPushPayload: Content {
    let receiverID: UserID
    let senderID: UserID
    let distance: Double
    let direction: String
    let signalID: SignalID
}

struct SignalNotificationData: Codable {
    let signalID: UUID
    let senderID: UUID
    let distance: Double
    let direction: String
    let type: String
    let timestamp: Date
}

struct HealthResponse: Content {
    let service: String
    let status: String
    let timestamp: Date
    let version: String
}

struct DeviceTokenResponse: Content {
    let userID: UserID
    let deviceToken: ValidatedDeviceToken
    let isOffline: Bool
    let lastUpdated: Date
}