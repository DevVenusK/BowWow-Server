import Vapor
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

// MARK: - Route Handlers

/// 사용자 등록
func registerUser(req: Request) async throws -> CreateUserResponse {
    req.logger.info("🔄 Processing user registration request")
    
    let createUserRequest = try req.content.decode(CreateUserRequest.self)
    req.logger.info("📥 Decoded request: \(createUserRequest)")
    
    // Validation
    let validationResult = validateUser(createUserRequest)
    let validatedRequest = try validationResult.get()
    req.logger.info("✅ Validation passed")
    
    // Forward to User Service
    let serviceURLs = req.application.storage[ServiceURLsKey.self]!
    let userServiceURL = "\(serviceURLs.userService)/users/register"
    req.logger.info("🎯 Forwarding to UserService at: \(userServiceURL)")
    
    do {
        let result = try await forwardRequest(
            to: userServiceURL,
            method: .POST,
            body: validatedRequest,
            as: CreateUserResponse.self,
            on: req
        )
        req.logger.info("✅ User registration successful")
        return result
    } catch {
        req.logger.error("❌ User registration failed: \(error)")
        throw error
    }
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

/// 신호 전송
func sendSignal(req: Request) async throws -> SignalResponse {
    let signalRequest = try req.content.decode(SignalRequest.self)
    
    // Validation
    let validationResult = validateSignal(signalRequest)
    let validatedRequest = try validationResult.get()
    
    // Forward to Signal Service
    let serviceURLs = req.application.storage[ServiceURLsKey.self]!
    let signalServiceURL = "\(serviceURLs.signalService)/signals"
    
    return try await forwardRequest(
        to: signalServiceURL,
        method: .POST,
        body: validatedRequest,
        as: SignalResponse.self,
        on: req
    )
}

/// 수신된 신호 조회
func getReceivedSignals(req: Request) async throws -> [ReceivedSignal] {
    guard let userID = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    // Forward to Signal Service
    let serviceURLs = req.application.storage[ServiceURLsKey.self]!
    let signalServiceURL = "\(serviceURLs.signalService)/signals/received/\(userID)"
    
    return try await forwardGetRequest(
        to: signalServiceURL,
        as: [ReceivedSignal].self,
        on: req
    )
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

/// 위치 업데이트
func updateLocation(req: Request) async throws -> Response {
    let locationRequest = try req.content.decode(LocationUpdateRequest.self)
    
    // Validation
    let validationResult = validateLocation(locationRequest)
    let validatedRequest = try validationResult.get()
    
    // Forward to Location Service
    let serviceURLs = req.application.storage[ServiceURLsKey.self]!
    let locationServiceURL = "\(serviceURLs.locationService)/locations/update"
    
    return try await forwardRequest(
        to: locationServiceURL,
        method: .POST,
        body: validatedRequest,
        on: req
    )
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