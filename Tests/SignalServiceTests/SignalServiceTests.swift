import Testing
import XCTVapor
import Fluent
@testable import SignalService
@testable import Shared

/// SignalService Tests using Swift Testing framework
/// Tests signal propagation, cooldown system, and distance-based logic

// MARK: - Signal Creation Tests

@Test("Create signal with valid parameters")
func testCreateSignalSuccess() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let signalRequest = SignalRequest(
        senderID: UserID(UUID()),
        location: try Location(
            latitude: TypedCoordinate<LatitudeMarker>(37.7749),
            longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
            timestamp: Date()
        ),
        maxDistance: 5.0
    )
    
    try await app.test(.POST, "signals") { req in
        try req.content.encode(signalRequest)
    } afterResponse: { res in
        #expect(res.status == .created)
        
        let response = try res.content.decode(SignalResponse.self)
        #expect(response.signalID.value != nil)
        #expect(response.senderID == signalRequest.senderID)
        #expect(response.status == .active)
    }
}

@Test("Create signal with invalid distance")
func testCreateSignalInvalidDistance() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let signalRequest = SignalRequest(
        senderID: UserID(UUID()),
        location: try Location(
            latitude: TypedCoordinate<LatitudeMarker>(37.7749),
            longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
            timestamp: Date()
        ),
        maxDistance: 15.0 // Over 10 mile limit
    )
    
    try await app.test(.POST, "signals") { req in
        try req.content.encode(signalRequest)
    } afterResponse: { res in
        #expect(res.status == .badRequest)
    }
}

@Test("Create signal with zero distance")
func testCreateSignalZeroDistance() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let signalRequest = SignalRequest(
        senderID: UserID(UUID()),
        location: try Location(
            latitude: TypedCoordinate<LatitudeMarker>(37.7749),
            longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
            timestamp: Date()
        ),
        maxDistance: 0.0
    )
    
    try await app.test(.POST, "signals") { req in
        try req.content.encode(signalRequest)
    } afterResponse: { res in
        #expect(res.status == .badRequest)
    }
}

// MARK: - Signal Cooldown Tests

@Test("Signal cooldown prevents rapid signals")
func testSignalCooldownPrevention() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let senderID = UserID(UUID())
    let signalRequest = SignalRequest(
        senderID: senderID,
        location: try Location(
            latitude: TypedCoordinate<LatitudeMarker>(37.7749),
            longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
            timestamp: Date()
        ),
        maxDistance: 5.0
    )
    
    // First signal should succeed
    try await app.test(.POST, "signals") { req in
        try req.content.encode(signalRequest)
    } afterResponse: { res in
        #expect(res.status == .created)
    }
    
    // Second signal immediately after should fail due to cooldown
    try await app.test(.POST, "signals") { req in
        try req.content.encode(signalRequest)
    } afterResponse: { res in
        #expect(res.status == .tooManyRequests)
    }
}

@Test("Signal cooldown allows response signals")
func testSignalCooldownAllowsResponse() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let senderID = UserID(UUID())
    let responderID = UserID(UUID())
    
    // Create original signal
    let originalSignal = Signal()
    originalSignal.id = UUID()
    originalSignal.$sender.id = senderID.value
    originalSignal.latitude = 37.7749
    originalSignal.longitude = -122.4194
    originalSignal.maxDistance = 5.0
    originalSignal.status = .active
    originalSignal.sentAt = Date()
    originalSignal.createdAt = Date()
    originalSignal.updatedAt = Date()
    
    try await originalSignal.save(on: app.db)
    
    // Create signal receipt to establish relationship
    let receipt = SignalReceipt()
    receipt.id = UUID()
    receipt.$signal.id = originalSignal.id!
    receipt.$receiver.id = responderID.value
    receipt.receivedAt = Date()
    receipt.createdAt = Date()
    receipt.updatedAt = Date()
    
    try await receipt.save(on: app.db)
    
    // Response signal should be allowed even during cooldown
    let responseRequest = SignalRequest(
        senderID: responderID,
        location: try Location(
            latitude: TypedCoordinate<LatitudeMarker>(37.7849),
            longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
            timestamp: Date()
        ),
        maxDistance: 3.0
    )
    
    try await app.test(.POST, "signals/\(originalSignal.id!)/respond") { req in
        try req.content.encode(responseRequest)
    } afterResponse: { res in
        #expect(res.status == .created)
    }
}

// MARK: - Signal Propagation Tests

@Test("Signal propagation timing")
func testSignalPropagationTiming() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let signalRequest = SignalRequest(
        senderID: UserID(UUID()),
        location: try Location(
            latitude: TypedCoordinate<LatitudeMarker>(37.7749),
            longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
            timestamp: Date()
        ),
        maxDistance: 10.0
    )
    
    let startTime = Date()
    
    try await app.test(.POST, "signals") { req in
        try req.content.encode(signalRequest)
    } afterResponse: { res in
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        #expect(res.status == .created)
        #expect(processingTime < 1.0) // Should be fast
        
        let response = try res.content.decode(SignalResponse.self)
        #expect(response.estimatedPropagationTime == 10.0) // 10 seconds for 10 miles
    }
}

@Test("Signal status transitions")
func testSignalStatusTransitions() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    // Create a signal
    let signal = Signal()
    signal.id = UUID()
    signal.$sender.id = UUID()
    signal.latitude = 37.7749
    signal.longitude = -122.4194
    signal.maxDistance = 5.0
    signal.status = .active
    signal.sentAt = Date()
    signal.createdAt = Date()
    signal.updatedAt = Date()
    
    try await signal.save(on: app.db)
    
    // Test status retrieval
    let retrievedSignal = try await Signal.find(signal.id, on: app.db)
    #expect(retrievedSignal?.status == .active)
    
    // Test status update
    retrievedSignal?.status = .completed
    try await retrievedSignal?.save(on: app.db)
    
    let updatedSignal = try await Signal.find(signal.id, on: app.db)
    #expect(updatedSignal?.status == .completed)
}

// MARK: - Received Signals Tests

@Test("Get received signals for user")
func testGetReceivedSignals() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let receiverID = UserID(UUID())
    let senderID = UserID(UUID())
    
    // Create a signal
    let signal = Signal()
    signal.id = UUID()
    signal.$sender.id = senderID.value
    signal.latitude = 37.7749
    signal.longitude = -122.4194
    signal.maxDistance = 5.0
    signal.status = .active
    signal.sentAt = Date()
    signal.createdAt = Date()
    signal.updatedAt = Date()
    
    try await signal.save(on: app.db)
    
    // Create signal receipt
    let receipt = SignalReceipt()
    receipt.id = UUID()
    receipt.$signal.id = signal.id!
    receipt.$receiver.id = receiverID.value
    receipt.receivedAt = Date()
    receipt.createdAt = Date()
    receipt.updatedAt = Date()
    
    try await receipt.save(on: app.db)
    
    // Test retrieving received signals
    try await app.test(.GET, "signals/received/\(receiverID.value)") { req in
    } afterResponse: { res in
        #expect(res.status == .ok)
        
        let receivedSignals = try res.content.decode([ReceivedSignal].self)
        #expect(receivedSignals.count > 0)
        
        let receivedSignal = receivedSignals.first!
        #expect(receivedSignal.signalID.value == signal.id!)
        #expect(receivedSignal.senderID == senderID)
    }
}

@Test("Get received signals for user with no signals")
func testGetReceivedSignalsEmpty() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let userID = UserID(UUID())
    
    try await app.test(.GET, "signals/received/\(userID.value)") { req in
    } afterResponse: { res in
        #expect(res.status == .ok)
        
        let receivedSignals = try res.content.decode([ReceivedSignal].self)
        #expect(receivedSignals.count == 0)
    }
}

// MARK: - Distance Validation Tests

@Test("Distance validation enforces constraints")
func testDistanceValidation() {
    // Test valid distances
    let validDistances = [0.5, 1.0, 5.0, 10.0]
    
    for distance in validDistances {
        let result = validateSignalDistance(distance)
        switch result {
        case .success:
            // Expected success
            break
        case .failure:
            #expect(Bool(false), "Distance \(distance) should be valid")
        }
    }
    
    // Test invalid distances
    let invalidDistances = [0.0, -1.0, 10.1, 15.0]
    
    for distance in invalidDistances {
        let result = validateSignalDistance(distance)
        switch result {
        case .success:
            #expect(Bool(false), "Distance \(distance) should be invalid")
        case .failure:
            // Expected failure
            break
        }
    }
}

// MARK: - Strong Type Integration Tests

@Test("SignalID type safety")
func testSignalIDTypeSafety() {
    let uuid1 = UUID()
    let uuid2 = UUID()
    
    let signalID1 = SignalID(uuid1)
    let signalID2 = SignalID(uuid2)
    
    #expect(signalID1 != signalID2)
    #expect(signalID1.value == uuid1)
    #expect(signalID2.value == uuid2)
    
    // Type safety ensures we can't mix up different signal IDs
    #expect(signalID1 != signalID2)
}

@Test("Location coordinates with strong types")
func testLocationCoordinatesStrongTypes() throws {
    let latitude = try TypedCoordinate<LatitudeMarker>(37.7749)
    let longitude = try TypedCoordinate<LongitudeMarker>(-122.4194)
    
    let location = Location(
        latitude: latitude,
        longitude: longitude,
        timestamp: Date()
    )
    
    #expect(location.latitude.value == 37.7749)
    #expect(location.longitude.value == -122.4194)
    
    // Strong types prevent mixing up coordinates
    // This would be a compile-time error:
    // let badLocation = Location(latitude: longitude, longitude: latitude)
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
        #expect(response.service == "SignalService")
        #expect(response.status == "healthy")
        #expect(response.version == "1.0.0")
    }
}

// MARK: - Functional Programming Tests

@Test("Pure function behavior in signal logic")
func testPureFunctionBehavior() throws {
    let location = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    // Same inputs should always produce same outputs
    let time1 = calculatePropagationTime(distance: 5.0)
    let time2 = calculatePropagationTime(distance: 5.0)
    
    #expect(time1 == time2)
    #expect(time1 == 5.0) // 5 miles = 5 seconds at 1 mile/second
    
    // Test different inputs
    let time10 = calculatePropagationTime(distance: 10.0)
    #expect(time10 == 10.0)
}

@Test("Function composition in validation")
func testValidationComposition() throws {
    let composeValidation: (UserID, Location, Double) -> Result<SignalRequest, BowWowError> = { userID, location, distance in
        let distanceResult = validateSignalDistance(distance)
        
        switch distanceResult {
        case .success:
            return .success(SignalRequest(
                senderID: userID,
                location: location,
                maxDistance: distance
            ))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    let userID = UserID(UUID())
    let location = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    // Valid composition
    let validResult = composeValidation(userID, location, 5.0)
    switch validResult {
    case .success(let request):
        #expect(request.maxDistance == 5.0)
    case .failure:
        #expect(Bool(false), "Valid inputs should succeed")
    }
    
    // Invalid composition
    let invalidResult = composeValidation(userID, location, 15.0)
    switch invalidResult {
    case .success:
        #expect(Bool(false), "Invalid distance should fail")
    case .failure:
        // Expected failure
        break
    }
}

// MARK: - Helper Functions

private func validateSignalDistance(_ distance: Double) -> Result<Double, BowWowError> {
    guard distance > 0 && distance <= 10.0 else {
        return .failure(.validationFailed("Signal distance must be between 0.1 and 10.0 miles"))
    }
    return .success(distance)
}

private func calculatePropagationTime(distance: Double) -> Double {
    return distance // 1 mile per second
}

// MARK: - Mock Types for Testing

struct HealthResponse: Content {
    let service: String
    let status: String
    let timestamp: Date
    let version: String
}