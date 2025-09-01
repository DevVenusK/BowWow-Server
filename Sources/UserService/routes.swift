import Vapor
import Fluent
import Shared

public func routes(_ app: Application) throws {
    
    // MARK: - Health Check
    app.get("health") { req -> HealthResponse in
        return HealthResponse(
            service: "UserService",
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // MARK: - User Routes
    let users = app.grouped("users")
    users.post("register", use: registerUser)
    users.put(":userID", "settings", use: updateUserSettings)
    users.get(":userID", use: getUser)
    users.get(":userID", "device-token", use: getDeviceToken) // Push Service용 내부 API
    
    app.logger.info("✅ User Service routes configured")
}

// MARK: - Route Handlers

/// 사용자 등록 - Strong Typed
func registerUser(req: Request) async throws -> CreateUserResponse {
    let createRequest = try req.content.decode(CreateUserRequest.self)
    
    // 기존 사용자 확인 (중복 deviceToken 방지)
    if let existingUser = try await User.query(on: req.db)
        .filter(\.$deviceToken == createRequest.deviceToken.value)
        .first() {
        return CreateUserResponse(
            userID: existingUser.toUserID(),
            settings: existingUser.toSettings(),
            createdAt: existingUser.createdAt
        )
    }
    
    // 새 사용자 생성
    let settings = createRequest.settings ?? UserSettings()
    let user = User(
        deviceToken: createRequest.deviceToken.value,
        isOffline: settings.isOffline,
        distanceUnit: settings.distanceUnit
    )
    
    try await user.save(on: req.db)
    
    return CreateUserResponse(
        userID: user.toUserID(),
        settings: settings,
        createdAt: user.createdAt
    )
}

/// 사용자 설정 업데이트
func updateUserSettings(req: Request) async throws -> Response {
    guard let userIDParam = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    let userID = UserID(userIDParam)
    let settings = try req.content.decode(UserSettings.self)
    
    guard let user = try await User.find(userID.value, on: req.db) else {
        throw Abort(.notFound, reason: "User not found")
    }
    
    // 설정 업데이트 with functional approach
    user.isOffline = settings.isOffline
    user.distanceUnit = settings.distanceUnit
    user.updatedAt = Date()
    
    try await user.save(on: req.db)
    
    return Response(status: .ok)
}

/// 사용자 조회
func getUser(req: Request) async throws -> CreateUserResponse {
    guard let userIDParam = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    let userID = UserID(userIDParam)
    
    guard let user = try await User.find(userID.value, on: req.db) else {
        throw Abort(.notFound, reason: "User not found")
    }
    
    return CreateUserResponse(
        userID: user.toUserID(),
        settings: user.toSettings(),
        createdAt: user.createdAt
    )
}

/// 디바이스 토큰 조회 - Push Service 전용 내부 API
func getDeviceToken(req: Request) async throws -> DeviceTokenResponse {
    guard let userIDParam = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    let userID = UserID(userIDParam)
    
    guard let user = try await User.find(userID.value, on: req.db) else {
        throw Abort(.notFound, reason: "User not found")
    }
    
    // 강타입 디바이스 토큰 검증 및 반환
    let validatedToken = try ValidatedDeviceToken.createOrThrow(user.deviceToken)
    
    return DeviceTokenResponse(
        userID: user.toUserID(),
        deviceToken: validatedToken,
        isOffline: user.isOffline,
        lastUpdated: user.updatedAt
    )
}

// MARK: - Response Types

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