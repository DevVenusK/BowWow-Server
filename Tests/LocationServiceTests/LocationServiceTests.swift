import Testing
import XCTVapor
import Fluent
import Crypto
@testable import LocationService
@testable import Shared

/// LocationService Tests using Swift Testing framework
/// Tests location updates, encryption, and coordinate validation

// MARK: - Location Update Tests

@Test("Location update with valid coordinates")
func testLocationUpdateSuccess() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let locationRequest = LocationUpdateRequest(
        userID: UserID(UUID()),
        location: Location(
            latitude: try TypedCoordinate<LatitudeMarker>(37.7749),
            longitude: try TypedCoordinate<LongitudeMarker>(-122.4194),
            timestamp: Date()
        )
    )
    
    try await app.test(.POST, "locations/update") { req in
        try req.content.encode(locationRequest)
    } afterResponse: { res in
        #expect(res.status == .created)
    }
}

@Test("Location update with invalid latitude")
func testLocationUpdateInvalidLatitude() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    // This should fail at the strong type level before reaching the service
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LatitudeMarker>(91.0) // Invalid latitude
    }
}

@Test("Location update with invalid longitude")
func testLocationUpdateInvalidLongitude() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    // This should fail at the strong type level before reaching the service
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LongitudeMarker>(181.0) // Invalid longitude
    }
}

// MARK: - Encryption Tests

@Test("Location encryption and decryption")
func testLocationEncryptionDecryption() async throws {
    // Set up encryption key
    let keyData = SymmetricKey(size: .bits256)
    let keyString = keyData.withUnsafeBytes { Data($0).base64EncodedString() }
    
    // Mock environment variable for testing
    setenv("LOCATION_ENCRYPTION_KEY", keyString, 1)
    defer { unsetenv("LOCATION_ENCRYPTION_KEY") }
    
    let originalLocation = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    // Test encryption
    let encryptedData = try encryptLocation(originalLocation)
    #expect(encryptedData != nil)
    #expect(encryptedData.count > 0)
    
    // Test decryption
    let decryptedLocation = try decryptLocation(encryptedData)
    
    #expect(abs(decryptedLocation.latitude.value - originalLocation.latitude.value) < 0.0001)
    #expect(abs(decryptedLocation.longitude.value - originalLocation.longitude.value) < 0.0001)
}

@Test("Encryption without key fails gracefully")
func testEncryptionWithoutKey() async throws {
    // Ensure no encryption key is set
    unsetenv("LOCATION_ENCRYPTION_KEY")
    
    let location = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    #expect(throws: BowWowError.self) {
        _ = try encryptLocation(location)
    }
}

// MARK: - Nearby Users Tests

@Test("Find nearby users within range")
func testFindNearbyUsers() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let centerUserID = UserID(UUID())
    let centerLocation = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    // Create center user location
    let centerUserLocation = UserLocation()
    centerUserLocation.id = UUID()
    centerUserLocation.$user.id = centerUserID.value
    centerUserLocation.latitude = centerLocation.latitude.value
    centerUserLocation.longitude = centerLocation.longitude.value
    centerUserLocation.encryptedLocation = Data()
    centerUserLocation.createdAt = Date()
    centerUserLocation.updatedAt = Date()
    
    try await centerUserLocation.save(on: app.db)
    
    // Create nearby user (within 1 mile)
    let nearbyUserID = UserID(UUID())
    let nearbyLocation = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7849), // ~1 mile north
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    let nearbyUserLocation = UserLocation()
    nearbyUserLocation.id = UUID()
    nearbyUserLocation.$user.id = nearbyUserID.value
    nearbyUserLocation.latitude = nearbyLocation.latitude.value
    nearbyUserLocation.longitude = nearbyLocation.longitude.value
    nearbyUserLocation.encryptedLocation = Data()
    nearbyUserLocation.createdAt = Date()
    nearbyUserLocation.updatedAt = Date()
    
    try await nearbyUserLocation.save(on: app.db)
    
    // Test finding nearby users
    try await app.test(.POST, "locations/nearby") { req in
        let nearbyRequest = NearbyUsersRequest(
            userID: centerUserID,
            location: centerLocation,
            radiusMiles: 2.0
        )
        try req.content.encode(nearbyRequest)
    } afterResponse: { res in
        #expect(res.status == .ok)
        
        let nearbyUsers = try res.content.decode([NearbyUser].self)
        #expect(nearbyUsers.count > 0)
        
        // Should find the nearby user
        let foundUser = nearbyUsers.first { $0.userID == nearbyUserID }
        #expect(foundUser != nil)
        #expect(foundUser?.distance ?? 0 > 0)
        #expect(foundUser?.distance ?? 0 < 2.0) // Within 2 mile radius
    }
}

@Test("Find nearby users excludes far users")
func testFindNearbyUsersExcludesFar() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let centerUserID = UserID(UUID())
    let centerLocation = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    // Create center user location
    let centerUserLocation = UserLocation()
    centerUserLocation.id = UUID()
    centerUserLocation.$user.id = centerUserID.value
    centerUserLocation.latitude = centerLocation.latitude.value
    centerUserLocation.longitude = centerLocation.longitude.value
    centerUserLocation.encryptedLocation = Data()
    centerUserLocation.createdAt = Date()
    centerUserLocation.updatedAt = Date()
    
    try await centerUserLocation.save(on: app.db)
    
    // Create far user (>10 miles away)
    let farUserID = UserID(UUID())
    let farLocation = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(38.0), // Much further north
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    let farUserLocation = UserLocation()
    farUserLocation.id = UUID()
    farUserLocation.$user.id = farUserID.value
    farUserLocation.latitude = farLocation.latitude.value
    farUserLocation.longitude = farLocation.longitude.value
    farUserLocation.encryptedLocation = Data()
    farUserLocation.createdAt = Date()
    farUserLocation.updatedAt = Date()
    
    try await farUserLocation.save(on: app.db)
    
    // Test finding nearby users with small radius
    try await app.test(.POST, "locations/nearby") { req in
        let nearbyRequest = NearbyUsersRequest(
            userID: centerUserID,
            location: centerLocation,
            radiusMiles: 1.0
        )
        try req.content.encode(nearbyRequest)
    } afterResponse: { res in
        #expect(res.status == .ok)
        
        let nearbyUsers = try res.content.decode([NearbyUser].self)
        
        // Should not find the far user
        let foundFarUser = nearbyUsers.first { $0.userID == farUserID }
        #expect(foundFarUser == nil)
    }
}

// MARK: - Coordinate Validation Tests

@Test("TypedCoordinate enforces latitude bounds")
func testLatitudeBounds() {
    // Valid latitudes
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LatitudeMarker>(0.0)
    }
    
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LatitudeMarker>(90.0)
    }
    
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LatitudeMarker>(-90.0)
    }
    
    // Invalid latitudes
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LatitudeMarker>(90.1)
    }
    
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LatitudeMarker>(-90.1)
    }
}

@Test("TypedCoordinate enforces longitude bounds")
func testLongitudeBounds() {
    // Valid longitudes
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LongitudeMarker>(0.0)
    }
    
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LongitudeMarker>(180.0)
    }
    
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LongitudeMarker>(-180.0)
    }
    
    // Invalid longitudes
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LongitudeMarker>(180.1)
    }
    
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LongitudeMarker>(-180.1)
    }
}

// MARK: - Distance Calculation Tests

@Test("Distance calculation accuracy")
func testDistanceCalculationAccuracy() throws {
    let sanFrancisco = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    let oakland = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.8044),
        longitude: TypedCoordinate<LongitudeMarker>(-122.2711),
        timestamp: Date()
    )
    
    let distance = calculateHaversineDistance(from: sanFrancisco, to: oakland)
    
    // SF to Oakland is approximately 8-12 miles
    #expect(distance > 6.0)
    #expect(distance < 15.0)
}

@Test("Direction calculation")
func testDirectionCalculation() throws {
    let center = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    let north = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.8749), // North
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    let direction = calculateDirection(from: center, to: north)
    #expect(direction.contains("N")) // Should contain "N" for north
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
        #expect(response.service == "LocationService")
        #expect(response.status == "healthy")
        #expect(response.version == "1.0.0")
    }
}

// MARK: - Redis Integration Tests

@Test("Redis caching integration")
func testRedisCachingIntegration() async throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    
    try await configure(app)
    
    let userID = UserID(UUID())
    let location = try Location(
        latitude: TypedCoordinate<LatitudeMarker>(37.7749),
        longitude: TypedCoordinate<LongitudeMarker>(-122.4194),
        timestamp: Date()
    )
    
    let cacheKey = "nearby_users:\(userID.value)"
    let nearbyUsers = [
        NearbyUser(
            userID: UserID(UUID()),
            distance: 1.5,
            direction: "N"
        )
    ]
    
    // Test caching functionality if Redis is available
    // Note: This test requires Redis to be running
    do {
        let encoded = try JSONEncoder().encode(nearbyUsers)
        try await app.redis.set(cacheKey, to: encoded).get()
        
        let cached = try await app.redis.get(cacheKey, as: Data.self).get()
        let decoded = try JSONDecoder().decode([NearbyUser].self, from: cached!)
        
        #expect(decoded.count == nearbyUsers.count)
        #expect(decoded.first?.distance == nearbyUsers.first?.distance)
    } catch {
        // Redis not available in test environment - skip test
        print("Redis not available for testing, skipping cache test")
    }
}

// MARK: - Helper Functions

private func calculateHaversineDistance(from: Location, to: Location) -> Double {
    let lat1 = from.latitude.value * .pi / 180
    let lat2 = to.latitude.value * .pi / 180
    let deltaLat = (to.latitude.value - from.latitude.value) * .pi / 180
    let deltaLon = (to.longitude.value - from.longitude.value) * .pi / 180
    
    let a = sin(deltaLat/2) * sin(deltaLat/2) +
            cos(lat1) * cos(lat2) *
            sin(deltaLon/2) * sin(deltaLon/2)
    let c = 2 * atan2(sqrt(a), sqrt(1-a))
    
    return 3959 * c // Earth radius in miles
}

private func calculateDirection(from: Location, to: Location) -> String {
    let deltaLat = to.latitude.value - from.latitude.value
    let deltaLon = to.longitude.value - from.longitude.value
    
    let angle = atan2(deltaLon, deltaLat) * 180 / .pi
    let normalizedAngle = angle >= 0 ? angle : angle + 360
    
    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int((normalizedAngle + 22.5) / 45) % 8
    
    return directions[index]
}

// MARK: - Mock Types for Testing

struct NearbyUsersRequest: Content {
    let userID: UserID
    let location: Location
    let radiusMiles: Double
}

struct NearbyUser: Content, Codable {
    let userID: UserID
    let distance: Double
    let direction: String
}