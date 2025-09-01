import Testing
import XCTVapor
import Fluent
@testable import UserService
@testable import Shared

/// UserService Tests using Swift Testing framework
/// Tests user registration, device token validation, and settings management

// MARK: - User Registration Tests

@Test("User registration with valid device token")
func testUserRegistrationSuccess() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let validDeviceToken = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0"
    
    let createUserRequest = CreateUserRequest(
        deviceToken: validDeviceToken,
        settings: UserSettings(
            isOffline: false,
            distanceUnit: .mile
        )
    )
    
    try await app.test(.POST, "users/register") { req in
        try req.content.encode(createUserRequest)
    } afterResponse: { res in
        #expect(res.status == .created)
        
        let response = try res.content.decode(CreateUserResponse.self)
        #expect(response.deviceToken.value == validDeviceToken)
        #expect(response.settings.isOffline == false)
        #expect(response.settings.distanceUnit == .mile)
        #expect(response.userID.value != nil)
    }
}

@Test("User registration with invalid device token")
func testUserRegistrationInvalidToken() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let invalidDeviceToken = "invalid_token"
    
    let createUserRequest = CreateUserRequest(
        deviceToken: invalidDeviceToken,
        settings: UserSettings(
            isOffline: false,
            distanceUnit: .mile
        )
    )
    
    try await app.test(.POST, "users/register") { req in
        try req.content.encode(createUserRequest)
    } afterResponse: { res in
        #expect(res.status == .badRequest)
    }
}

@Test("User registration with empty device token")
func testUserRegistrationEmptyToken() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let createUserRequest = CreateUserRequest(
        deviceToken: "",
        settings: UserSettings(
            isOffline: false,
            distanceUnit: .mile
        )
    )
    
    try await app.test(.POST, "users/register") { req in
        try req.content.encode(createUserRequest)
    } afterResponse: { res in
        #expect(res.status == .badRequest)
    }
}

// MARK: - User Settings Tests

@Test("Update user settings successfully")
func testUpdateUserSettingsSuccess() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    // First create a user
    let validDeviceToken = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0"
    
    let createUserRequest = CreateUserRequest(
        deviceToken: validDeviceToken,
        settings: UserSettings(
            isOffline: false,
            distanceUnit: .mile
        )
    )
    
    var userID: UUID!
    
    try await app.test(.POST, "users/register") { req in
        try req.content.encode(createUserRequest)
    } afterResponse: { res in
        let response = try res.content.decode(CreateUserResponse.self)
        userID = response.userID.value
    }
    
    // Now update settings
    let newSettings = UserSettings(
        isOffline: true,
        distanceUnit: .kilometer
    )
    
    try await app.test(.PUT, "users/\(userID!)/settings") { req in
        try req.content.encode(newSettings)
    } afterResponse: { res in
        #expect(res.status == .ok)
    }
}

@Test("Update non-existent user settings")
func testUpdateNonExistentUserSettings() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let randomUserID = UUID()
    let settings = UserSettings(
        isOffline: true,
        distanceUnit: .kilometer
    )
    
    try await app.test(.PUT, "users/\(randomUserID)/settings") { req in
        try req.content.encode(settings)
    } afterResponse: { res in
        #expect(res.status == .notFound)
    }
}

// MARK: - Device Token Retrieval Tests

@Test("Get device token for existing user")
func testGetDeviceTokenSuccess() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    // First create a user
    let validDeviceToken = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0"
    
    let createUserRequest = CreateUserRequest(
        deviceToken: validDeviceToken,
        settings: UserSettings(
            isOffline: false,
            distanceUnit: .mile
        )
    )
    
    var userID: UUID!
    
    try await app.test(.POST, "users/register") { req in
        try req.content.encode(createUserRequest)
    } afterResponse: { res in
        let response = try res.content.decode(CreateUserResponse.self)
        userID = response.userID.value
    }
    
    // Now get device token
    try await app.test(.GET, "users/\(userID!)/device-token") { req in
    } afterResponse: { res in
        #expect(res.status == .ok)
        
        let response = try res.content.decode(DeviceTokenResponse.self)
        #expect(response.deviceToken.value == validDeviceToken)
        #expect(response.userID.value == userID)
    }
}

@Test("Get device token for non-existent user")
func testGetDeviceTokenNotFound() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let randomUserID = UUID()
    
    try await app.test(.GET, "users/\(randomUserID)/device-token") { req in
    } afterResponse: { res in
        #expect(res.status == .notFound)
    }
}

// MARK: - User Retrieval Tests

@Test("Get user info for existing user")
func testGetUserSuccess() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    // First create a user
    let validDeviceToken = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0"
    
    let createUserRequest = CreateUserRequest(
        deviceToken: validDeviceToken,
        settings: UserSettings(
            isOffline: false,
            distanceUnit: .mile
        )
    )
    
    var userID: UUID!
    
    try await app.test(.POST, "users/register") { req in
        try req.content.encode(createUserRequest)
    } afterResponse: { res in
        let response = try res.content.decode(CreateUserResponse.self)
        userID = response.userID.value
    }
    
    // Now get user info
    try await app.test(.GET, "users/\(userID!)") { req in
    } afterResponse: { res in
        #expect(res.status == .ok)
        
        let response = try res.content.decode(CreateUserResponse.self)
        #expect(response.userID.value == userID)
        #expect(response.deviceToken.value == validDeviceToken)
        #expect(response.settings.isOffline == false)
        #expect(response.settings.distanceUnit == .mile)
    }
}

// MARK: - Health Check Tests

@Test("Health check endpoint")
func testHealthCheck() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    try await app.test(.GET, "health") { req in
    } afterResponse: { res in
        #expect(res.status == .ok)
        
        let response = try res.content.decode(HealthResponse.self)
        #expect(response.service == "UserService")
        #expect(response.status == "healthy")
        #expect(response.version == "1.0.0")
    }
}

// MARK: - Strong Type Validation Tests

@Test("Device token validation enforces strong typing")
func testDeviceTokenStrongTyping() async throws {
    // Test that our strong types prevent invalid data at compile time
    let validToken = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0"
    
    #expect(throws: Never.self) {
        _ = try ValidatedDeviceToken(validToken)
    }
    
    let invalidTokens = [
        "short_token",
        "",
        "not_hex_characters_ZZZZ" + String(repeating: "a", 100)
    ]
    
    for invalidToken in invalidTokens {
        #expect(throws: BowWowError.self) {
            _ = try ValidatedDeviceToken(invalidToken)
        }
    }
}

@Test("UserID type safety")
func testUserIDTypeSafety() {
    let uuid1 = UUID()
    let uuid2 = UUID()
    
    let userID1 = UserID(uuid1)
    let userID2 = UserID(uuid2)
    
    // Type safety ensures we can't mix up different IDs
    #expect(userID1 != userID2)
    #expect(userID1.value == uuid1)
    #expect(userID2.value == uuid2)
    
    // UserID wraps UUID but provides type safety
    #expect(userID1.value is UUID)
}

// MARK: - Database Integration Tests

@Test("Database operations work with strong types")
func testDatabaseIntegrationWithStrongTypes() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    // Create a user with strong types
    let deviceToken = try ValidatedDeviceToken("a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0")
    let userID = UserID(UUID())
    
    let user = User()
    user.id = userID.value
    user.deviceToken = deviceToken.value
    user.isOffline = false
    user.distanceUnit = DistanceUnit.mile
    user.createdAt = Date()
    user.updatedAt = Date()
    
    // Test database save with strong types
    try await user.save(on: app.db)
    
    // Test database retrieval maintains strong types  
    let retrievedUser = try await User.find(userID.value, on: app.db)
    #expect(retrievedUser != nil)
    #expect(retrievedUser?.deviceToken == deviceToken.value)
}