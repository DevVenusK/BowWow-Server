import Vapor
import Fluent
import Shared

public func routes(_ app: Application) throws {
    
    // MARK: - Health Check
    app.get("health") { req -> HealthResponse in
        return HealthResponse(
            service: "Gateway",
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // MARK: - Debug Routes (temporary)
    app.get("debug", "user-service") { req -> String in
        let serviceURLs = req.application.storage[ServiceURLsKey.self]!
        let userServiceURL = "\(serviceURLs.userService)/health"
        
        do {
            let response = try await req.client.get(URI(string: userServiceURL))
            return "UserService Status: \(response.status) - Body: \(response.body?.getString(at: 0, length: response.body?.readableBytes ?? 0) ?? "no body")"
        } catch {
            return "UserService Error: \(error)"
        }
    }
    
    app.get("debug", "database") { req -> String in
        do {
            let count = try await User.query(on: req.db).count()
            return "Database Status: OK - User count: \(count)"
        } catch {
            return "Database Error: \(error)"
        }
    }
    
    // MARK: - API v1 Routes
    let api = app.grouped("api", "v1")
    
    // User Management Routes
    let users = api.grouped("users")
    users.post("register", use: registerUser)
    users.put(":userID", "settings", use: updateUserSettings)
    
    // Signal Routes
    let signals = api.grouped("signals")
    signals.post(use: sendSignal)
    signals.get("received", ":userID", use: getReceivedSignals)
    signals.post(":signalID", "respond", use: respondToSignal)
    
    // Location Routes
    let locations = api.grouped("locations")
    locations.post("update", use: updateLocation)
    
    app.logger.info("✅ Gateway routes configured")
}

// MARK: - Signal Processing Helpers

/// 신호를 받을 수 있는 주변 사용자들을 찾고 SignalReceipt 생성
private func processSignalReceipts(signal: Signal, on req: Request) async {
    do {
        req.logger.info("🔍 Finding nearby users for signal: \(signal.id?.uuidString ?? "unknown")")
        
        // 신호 범위 내의 사용자들을 찾음 (간단한 거리 계산)
        let maxDistanceKm = Double(signal.maxDistance)
        
        // TODO: [POSTGIS-005] PostGIS ST_DWithin 함수로 최적화 필요
        let nearbyLocations = try await UserLocation.query(on: req.db)
            .filter(\.$expiresAt > Date()) // 만료되지 않은 위치만
            .all()
        
        var receiptsCreated = 0
        
        for location in nearbyLocations {
            // 발신자 본인은 제외
            if location.$user.id == signal.$sender.id {
                continue
            }
            
            // 간단한 거리 계산 (하버사인 공식)
            let distance = calculateDistance(
                lat1: signal.latitude,
                lng1: signal.longitude,
                lat2: location.latitude,
                lng2: location.longitude
            )
            
            if distance <= maxDistanceKm {
                // 방향 계산
                let direction = calculateDirection(
                    fromLat: location.latitude,
                    fromLng: location.longitude,
                    toLat: signal.latitude,
                    toLng: signal.longitude
                )
                
                // SignalReceipt 생성
                let receipt = SignalReceipt(
                    signalID: signal.id ?? UUID(),
                    receiverID: UserID(location.$user.id),
                    distance: distance,
                    direction: direction,
                    responded: false
                )
                
                try await receipt.save(on: req.db)
                receiptsCreated += 1
            }
        }
        
        req.logger.info("📨 Created \(receiptsCreated) signal receipts for signal: \(signal.id?.uuidString ?? "unknown")")
        
    } catch {
        req.logger.error("❌ Error processing signal receipts: \(error)")
    }
}

/// 두 지점 간의 거리 계산 (하버사인 공식, km 단위)
private func calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
    let earthRadiusKm = 6371.0
    
    let dLat = (lat2 - lat1) * .pi / 180
    let dLng = (lng2 - lng1) * .pi / 180
    
    let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLng / 2) * sin(dLng / 2)
    
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    
    return earthRadiusKm * c
}

/// 방향 계산 (8방향)
private func calculateDirection(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double) -> String {
    let dLat = toLat - fromLat
    let dLng = toLng - fromLng
    
    let angle = atan2(dLng, dLat) * 180 / .pi
    let normalizedAngle = angle < 0 ? angle + 360 : angle
    
    switch normalizedAngle {
    case 0..<22.5, 337.5...360:
        return "북"
    case 22.5..<67.5:
        return "북동"
    case 67.5..<112.5:
        return "동"
    case 112.5..<157.5:
        return "남동"
    case 157.5..<202.5:
        return "남"
    case 202.5..<247.5:
        return "남서"
    case 247.5..<292.5:
        return "서"
    case 292.5..<337.5:
        return "북서"
    default:
        return "북"
    }
}

// MARK: - Route Handlers

/// 사용자 등록 - Direct Database Access (Temporary Fix)
func registerUser(req: Request) async throws -> CreateUserResponse {
    req.logger.info("🔄 Processing user registration request directly in Gateway")
    
    let createUserRequest = try req.content.decode(CreateUserRequest.self)
    req.logger.info("📥 Decoded request: \(createUserRequest)")
    
    // Validation
    let validationResult = validateUser(createUserRequest)
    let validatedRequest = try validationResult.get()
    req.logger.info("✅ Validation passed")
    
    // Direct database access instead of forwarding to UserService
    req.logger.info("🎯 Processing user registration directly in Gateway")
    
    // Check for existing user (prevent duplicate deviceToken)
    if let existingUser = try await User.query(on: req.db)
        .filter(\.$deviceToken == validatedRequest.deviceToken.value)
        .first() {
        req.logger.info("👤 Found existing user, returning existing data")
        return CreateUserResponse(
            userID: existingUser.toUserID(),
            settings: existingUser.toSettings(),
            createdAt: existingUser.createdAt
        )
    }
    
    // Create new user
    let settings = validatedRequest.settings ?? UserSettings()
    let user = User(
        deviceToken: validatedRequest.deviceToken.value,
        isOffline: settings.isOffline,
        distanceUnit: settings.distanceUnit
    )
    
    try await user.save(on: req.db)
    req.logger.info("✅ User created successfully with ID: \(user.id?.uuidString ?? "unknown")")
    
    return CreateUserResponse(
        userID: user.toUserID(),
        settings: settings,
        createdAt: user.createdAt
    )
}

/// 사용자 설정 업데이트
func updateUserSettings(req: Request) async throws -> Response {
    guard let userID = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    let settings = try req.content.decode(UserSettings.self)
    
    // Forward to User Service
    let serviceURLs = req.application.storage[ServiceURLsKey.self]!
    let userServiceURL = "\(serviceURLs.userService)/users/\(userID)/settings"
    
    return try await forwardRequest(
        to: userServiceURL,
        method: .PUT,
        body: settings,
        on: req
    )
}

/// 신호 전송 - Direct Processing with Database Storage
func sendSignal(req: Request) async throws -> SignalResponse {
    req.logger.info("🔄 Processing signal request directly in Gateway")
    
    let signalRequest = try req.content.decode(SignalRequest.self)
    req.logger.info("📥 Decoded signal request: \(signalRequest)")
    
    // Validation
    let validationResult = validateSignal(signalRequest)
    let validatedRequest = try validationResult.get()
    req.logger.info("✅ Validation passed")
    
    // Create and save signal to database
    req.logger.info("🎯 Saving signal to database")
    
    let signal = Signal(
        senderID: validatedRequest.senderID,
        latitude: validatedRequest.location.latitude.value,
        longitude: validatedRequest.location.longitude.value,
        maxDistance: Int(validatedRequest.maxDistance?.value ?? 10.0),
        status: .active
    )
    
    try await signal.save(on: req.db)
    req.logger.info("💾 Signal saved to database with ID: \(signal.id?.uuidString ?? "unknown")")
    
    // Find nearby users and create signal receipts
    await processSignalReceipts(signal: signal, on: req)
    
    // Create response
    let signalResponse = SignalResponse(
        signalID: signal.id ?? UUID(),
        senderID: validatedRequest.senderID,
        sentAt: signal.sentAt,
        maxDistance: signal.maxDistance,
        status: signal.status
    )
    
    req.logger.info("✅ Signal processed successfully: \(signalResponse.signalID)")
    return signalResponse
}

/// 수신된 신호 조회 - Direct Database Processing
func getReceivedSignals(req: Request) async throws -> [ReceivedSignal] {
    req.logger.info("🔄 Processing received signals request directly in Gateway")
    
    guard let userID = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    req.logger.info("📥 Getting received signals for user: \(userID)")
    
    do {
        // 데이터베이스에서 수신된 신호들을 조회
        let signalReceipts = try await SignalReceipt.query(on: req.db)
            .filter(\.$receiver.$id == userID)
            .join(Signal.self, on: \SignalReceipt.$signal.$id == \Signal.$id)
            .join(User.self, on: \Signal.$sender.$id == \User.$id)
            .filter(Signal.self, \.$expiresAt > Date()) // 만료되지 않은 신호만
            .sort(Signal.self, \.$sentAt, .descending)
            .all()
        
        req.logger.info("📊 Found \(signalReceipts.count) signal receipts from database")
        
        // ReceivedSignal 형식으로 변환
        let receivedSignals = try signalReceipts.map { receipt in
            let signal = try receipt.joined(Signal.self)
            let sender = try signal.joined(User.self)
            
            return ReceivedSignal(
                signalID: signal.id ?? UUID(),
                senderID: UserID(sender.id ?? UUID()),
                distance: receipt.distance,
                direction: receipt.direction,
                receivedAt: receipt.receivedAt
            )
        }
        
        req.logger.info("✅ Processed \(receivedSignals.count) received signals for user: \(userID)")
        return receivedSignals
        
    } catch {
        req.logger.error("❌ Error querying received signals: \(error)")
        // 에러 발생 시 빈 배열 반환
        return []
    }
}

/// 신호 응답
func respondToSignal(req: Request) async throws -> SignalResponse {
    guard let signalID = req.parameters.get("signalID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid signal ID")
    }
    
    let signalRequest = try req.content.decode(SignalRequest.self)
    
    // Forward to Signal Service  
    let serviceURLs = req.application.storage[ServiceURLsKey.self]!
    let signalServiceURL = "\(serviceURLs.signalService)/signals/\(signalID)/respond"
    
    return try await forwardRequest(
        to: signalServiceURL,
        method: .POST,
        body: signalRequest,
        as: SignalResponse.self,
        on: req
    )
}

/// 위치 업데이트 - Direct Database Processing
func updateLocation(req: Request) async throws -> Response {
    req.logger.info("🔄 Processing location update directly in Gateway")
    
    let locationRequest = try req.content.decode(LocationUpdateRequest.self)
    req.logger.info("📥 Decoded location update request: \(locationRequest)")
    
    // Validation
    let validationResult = validateLocation(locationRequest)
    let validatedRequest = try validationResult.get()
    req.logger.info("✅ Location validation passed")
    
    do {
        // 기존 위치 삭제 (사용자당 최신 위치만 유지)
        try await UserLocation.query(on: req.db)
            .filter(\.$user.$id == validatedRequest.userID.value)
            .delete()
        
        // 새로운 위치 저장 (간단한 구현 - 실제로는 암호화 필요)
        let userLocation = UserLocation(
            userID: validatedRequest.userID,
            encryptedLatitude: String(validatedRequest.location.latitude.value), // TODO: 실제 암호화 구현
            encryptedLongitude: String(validatedRequest.location.longitude.value), // TODO: 실제 암호화 구현
            latitude: validatedRequest.location.latitude.value,
            longitude: validatedRequest.location.longitude.value
        )
        
        try await userLocation.save(on: req.db)
        req.logger.info("💾 Location saved for user: \(validatedRequest.userID.value)")
        
        return Response(status: .ok)
        
    } catch {
        req.logger.error("❌ Error saving location: \(error)")
        throw Abort(.internalServerError, reason: "Failed to save location")
    }
}

// MARK: - Helper Functions

/// HTTP 요청 전달 함수
func forwardRequest<T: Content, U: Codable>(
    to url: String,
    method: HTTPMethod,
    body: T? = nil,
    as responseType: U.Type,
    on req: Request
) async throws -> U {
    
    let response = try await forwardRequest(to: url, method: method, body: body, on: req)
    return try response.content.decode(responseType)
}

/// HTTP 요청 전달 함수 (Response 반환)
func forwardRequest<T: Content>(
    to url: String,
    method: HTTPMethod,
    body: T? = nil,
    on req: Request
) async throws -> Response {
    
    var clientRequest = ClientRequest(method: method, url: URI(string: url))
    
    // Copy headers
    for (name, value) in req.headers {
        if name != "host" && name != "content-length" {
            clientRequest.headers.replaceOrAdd(name: name, value: value)
        }
    }
    
    // Set body if provided
    if let body = body {
        try clientRequest.content.encode(body)
    }
    
    // Make request
    let clientResponse = try await req.client.send(clientRequest).get()
    
    // Convert ClientResponse to Response
    let response = Response(
        status: clientResponse.status,
        headers: clientResponse.headers,
        body: clientResponse.body != nil ? .init(buffer: clientResponse.body!) : .init()
    )
    
    return response
}

/// GET 요청 전용 함수 (body 없음)
func forwardGetRequest<U: Codable>(
    to url: String,
    as responseType: U.Type,
    on req: Request
) async throws -> U {
    
    var clientRequest = ClientRequest(method: .GET, url: URI(string: url))
    
    // Copy headers
    for (name, value) in req.headers {
        if name != "host" && name != "content-length" {
            clientRequest.headers.replaceOrAdd(name: name, value: value)
        }
    }
    
    // Make request
    let clientResponse = try await req.client.send(clientRequest).get()
    
    // Decode response
    return try clientResponse.content.decode(responseType)
}

// MARK: - Response Types

struct HealthResponse: Content {
    let service: String
    let status: String
    let timestamp: Date
    let version: String
}