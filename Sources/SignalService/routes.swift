import Vapor
import Fluent
import Shared

public func routes(_ app: Application) throws {
    
    // MARK: - Health Check
    app.get("health") { req -> HealthResponse in
        return HealthResponse(
            service: "SignalService",
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // MARK: - Signal Routes
    let signals = app.grouped("signals")
    signals.post(use: sendSignal)
    signals.get("received", ":userID", use: getReceivedSignals)
    signals.post(":signalID", "respond", use: respondToSignal)
    
    app.logger.info("✅ Signal Service routes configured")
}

// MARK: - Route Handlers

/// 신호 전송 - Strong Typed with Cooldown Logic
func sendSignal(req: Request) async throws -> SignalResponse {
    let signalRequest = try req.content.decode(SignalRequest.self)
    
    // 사용자 존재 및 상태 확인
    guard let sender = try await User.find(signalRequest.senderID.value, on: req.db) else {
        throw Abort(.notFound, reason: "Sender not found")
    }
    
    // 오프라인 사용자 체크
    if sender.isOffline {
        throw BowWowError.userOffline(signalRequest.senderID)
    }
    
    // 쿨다운 체크 (1시간 = 3600초)
    let oneHourAgo = Date().addingTimeInterval(-3600)
    let recentSignal = try await Signal.query(on: req.db)
        .filter(\.$sender.$id == signalRequest.senderID.value)
        .filter(\.$sentAt > oneHourAgo)
        .filter(\.$status == .active)
        .first()
    
    if let recent = recentSignal {
        let remaining = 3600 - Date().timeIntervalSince(recent.sentAt)
        if remaining > 0 {
            throw BowWowError.signalCooldown(remaining)
        }
    }
    
    // 강타입 빌더 패턴으로 신호 생성
    let maxDistance = signalRequest.maxDistance ?? (try! ValidatedDistance.createOrThrow(Double(sender.distanceUnit.maxDistance)))
    
    let strongSignal = try SignalBuilder()
        .sender(signalRequest.senderID)
        .location(signalRequest.location)
        .maxDistance(maxDistance)
        .build()
    
    // 데이터베이스에 저장 (레거시 모델 사용)
    let signal = Signal(
        senderID: strongSignal.senderID,
        latitude: strongSignal.location.latitude.value,
        longitude: strongSignal.location.longitude.value,
        maxDistance: Int(strongSignal.maxDistance.value)
    )
    
    try await signal.save(on: req.db)
    
    // 신호 전파 시작 (비동기)
    Task {
        await propagateSignal(signal: strongSignal, on: req.application, logger: req.logger)
    }
    
    req.logger.info("Signal sent by user: \(signalRequest.senderID.value)")
    
    return SignalResponse(
        signalID: signal.id ?? UUID(),
        senderID: signalRequest.senderID,
        sentAt: signal.sentAt,
        maxDistance: signal.maxDistance,
        status: signal.status
    )
}

/// 수신된 신호 조회
func getReceivedSignals(req: Request) async throws -> [ReceivedSignal] {
    guard let userIDParam = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    let userID = UserID(userIDParam)
    
    // 24시간 이내의 수신된 신호 조회
    let oneDayAgo = Date().addingTimeInterval(-86400)
    let receipts = try await SignalReceipt.query(on: req.db)
        .filter(\.$receiver.$id == userID.value)
        .filter(\.$receivedAt > oneDayAgo)
        .with(\.$signal) { signal in
            signal.with(\.$sender)
        }
        .sort(\.$receivedAt, .descending)
        .all()
    
    return receipts.map { $0.toReceivedSignal() }
}

/// 신호에 응답 (응답 신호는 쿨다운 예외)
func respondToSignal(req: Request) async throws -> SignalResponse {
    guard let signalIDParam = req.parameters.get("signalID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid signal ID")
    }
    
    let signalRequest = try req.content.decode(SignalRequest.self)
    
    // 원본 신호 확인
    guard let originalSignal = try await Signal.find(signalIDParam, on: req.db) else {
        throw Abort(.notFound, reason: "Original signal not found")
    }
    
    // 응답 권한 확인 (수신자인지 체크)
    let receipt = try await SignalReceipt.query(on: req.db)
        .filter(\.$signal.$id == signalIDParam)
        .filter(\.$receiver.$id == signalRequest.senderID.value)
        .first()
    
    guard let validReceipt = receipt else {
        throw Abort(.forbidden, reason: "Not authorized to respond to this signal")
    }
    
    // 응답 신호 생성 (쿨다운 무시)
    let responseSignal = Signal(
        senderID: signalRequest.senderID,
        latitude: signalRequest.location.latitude.value,
        longitude: signalRequest.location.longitude.value,
        maxDistance: Int(signalRequest.maxDistance?.value ?? 10.0)
    )
    
    try await responseSignal.save(on: req.db)
    
    // 응답 표시 업데이트
    validReceipt.responded = true
    validReceipt.respondedAt = Date()
    try await validReceipt.save(on: req.db)
    
    req.logger.info("Response signal sent by user: \(signalRequest.senderID.value)")
    
    return responseSignal.toResponse()
}

// MARK: - Signal Propagation Logic

/// 신호 전파 로직 - 1 mile per second over 10 miles
private func propagateSignal(signal: StrongSignal, on app: Application, logger: Logger) async {
    logger.info("Starting signal propagation for signal: \(signal.id.value)")
    
    // 주변 사용자 조회 (Location Service 호출)
    await withTaskGroup(of: Void.self) { group in
        // 10초 동안 1초마다 전파 (10 mile 범위)
        for second in 1...10 {
            group.addTask {
                // 1초 대기 후 해당 거리의 사용자들에게 신호 전송
                try? await Task.sleep(nanoseconds: UInt64(second * 1_000_000_000))
                
                do {
                    let currentRange = Double(second) // miles
                    let usersInRange = try await getNearbyUsersInRange(
                        location: signal.location,
                        minDistance: Double(second - 1),
                        maxDistance: currentRange,
                        excludeUserID: signal.senderID,
                        on: app
                    )
                    
                    // 범위 내 사용자들에게 신호 수신 기록 및 푸시 알림
                    for nearbyUser in usersInRange {
                        try await recordSignalReceipt(
                            signalID: signal.id,
                            receiverID: nearbyUser.userID,
                            distance: nearbyUser.distance,
                            direction: nearbyUser.direction,
                            on: app
                        )
                        
                        // Push Service 호출
                        await sendPushNotification(
                            to: nearbyUser.userID,
                            signal: signal,
                            distance: nearbyUser.distance,
                            direction: nearbyUser.direction,
                            on: app
                        )
                    }
                    
                    logger.info("Signal propagated to \(usersInRange.count) users at \(currentRange) miles")
                } catch {
                    logger.error("Signal propagation error at \(second) miles: \(error)")
                }
            }
        }
    }
    
    // 신호 만료 처리 (10분 후)
    try? await Task.sleep(nanoseconds: 600_000_000_000) // 10 minutes
    await expireSignal(signalID: signal.id, on: app, logger: logger)
}

// MARK: - Helper Functions

private func getNearbyUsersInRange(
    location: StrongLocation,
    minDistance: Double,
    maxDistance: Double,
    excludeUserID: UserID,
    on app: Application
) async throws -> [NearbyUser] {
    // Location Service 호출하여 주변 사용자 조회
    let locationServiceURL = "http://localhost:8002/locations/nearby/\(excludeUserID.value)?distance=\(maxDistance)"
    
    let response = try await app.client.get(URI(string: locationServiceURL))
    let allNearbyUsers = try response.content.decode([NearbyUser].self)
    
    // 거리 범위 필터링
    return allNearbyUsers.filter { user in
        user.distance >= minDistance && user.distance <= maxDistance
    }
}

private func recordSignalReceipt(
    signalID: SignalID,
    receiverID: UserID,
    distance: Double,
    direction: String,
    on app: Application
) async throws {
    
    let receipt = SignalReceipt(
        signalID: signalID.value,
        receiverID: receiverID,
        distance: distance,
        direction: direction
    )
    
    try await receipt.save(on: app.db)
}

private func sendPushNotification(
    to userID: UserID,
    signal: StrongSignal,
    distance: Double,
    direction: String,
    on app: Application
) async {
    
    // Push Service 호출
    let pushServiceURL = "http://localhost:8004/push/signal"
    let payload = SignalPushPayload(
        receiverID: userID,
        senderID: signal.senderID,
        distance: distance,
        direction: direction,
        signalID: signal.id
    )
    
    do {
        let _ = try await app.client.post(URI(string: pushServiceURL)) { req in
            try req.content.encode(payload)
        }
    } catch {
        app.logger.error("Failed to send push notification: \(error)")
    }
}

private func expireSignal(signalID: SignalID, on app: Application, logger: Logger) async {
    do {
        let signal = try await Signal.find(signalID.value, on: app.db)
        signal?.status = .expired
        try await signal?.save(on: app.db)
        logger.info("Signal expired: \(signalID.value)")
    } catch {
        logger.error("Failed to expire signal: \(error)")
    }
}

// MARK: - Response Types

struct HealthResponse: Content {
    let service: String
    let status: String
    let timestamp: Date
    let version: String
}

struct SignalPushPayload: Content {
    let receiverID: UserID
    let senderID: UserID
    let distance: Double
    let direction: String
    let signalID: SignalID
}

// Location Service와의 연동을 위한 임시 타입
struct NearbyUser: Content {
    let userID: UserID
    let distance: Double
    let direction: String
    let lastSeen: Date
}