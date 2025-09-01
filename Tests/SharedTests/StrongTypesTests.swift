import Testing
import Foundation
@testable import Shared

/// Strong Types Tests using Swift Testing framework
/// Tests the compile-time safety and validation of our type-driven development approach

// MARK: - Coordinate System Tests

@Test("Latitude validation works correctly")
func testLatitudeValidation() {
    // Valid latitudes
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LatitudeMarker>(37.7749)
    }
    
    // Invalid latitudes - too high
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LatitudeMarker>(91.0)
    }
    
    // Invalid latitudes - too low  
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LatitudeMarker>(-91.0)
    }
    
    // Boundary values
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LatitudeMarker>(90.0)
    }
    
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LatitudeMarker>(-90.0)
    }
}

@Test("Longitude validation works correctly")
func testLongitudeValidation() {
    // Valid longitudes
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LongitudeMarker>(-122.4194)
    }
    
    // Invalid longitudes - too high
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LongitudeMarker>(181.0)
    }
    
    // Invalid longitudes - too low
    #expect(throws: BowWowError.self) {
        _ = try TypedCoordinate<LongitudeMarker>(-181.0)
    }
    
    // Boundary values
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LongitudeMarker>(180.0)
    }
    
    #expect(throws: Never.self) {
        _ = try TypedCoordinate<LongitudeMarker>(-180.0)
    }
}

@Test("Location creation with legacy coordinates")
func testLocationCreation() async throws {
    let location = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: Date()
    )
    
    #expect(location.latitude == 37.7749)
    #expect(location.longitude == -122.4194)
}

// MARK: - Device Token Validation Tests

@Test("Device token validation - valid tokens")
func testValidDeviceTokens() {
    let validTokens = [
        "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0",
        "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    ]
    
    for token in validTokens {
        #expect(throws: Never.self) {
            _ = try ValidatedDeviceToken.createOrThrow(token)
        }
    }
}

@Test("Device token validation - invalid tokens")
func testInvalidDeviceTokens() {
    let invalidTokens = [
        "short",
        "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0Z", // Contains non-hex
        "", // Empty
        "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9" // Too short
    ]
    
    for token in invalidTokens {
        #expect(throws: BowWowError.self) {
            _ = try ValidatedDeviceToken.createOrThrow(token)
        }
    }
}

// MARK: - UserID NewType Tests

@Test("UserID creation and equality")
func testUserIDNewType() {
    let uuid1 = UUID()
    let uuid2 = UUID()
    
    let userID1 = UserID(uuid1)
    let userID2 = UserID(uuid1) // Same UUID
    let userID3 = UserID(uuid2) // Different UUID
    
    #expect(userID1 == userID2)
    #expect(userID1 != userID3)
    #expect(userID1.value == uuid1)
}

@Test("SignalID creation and uniqueness")
func testSignalIDNewType() {
    let uuid1 = UUID()
    let uuid2 = UUID()
    
    let signalID1 = SignalID(uuid1)
    let signalID2 = SignalID(uuid2)
    
    #expect(signalID1 != signalID2)
    #expect(signalID1.value == uuid1)
    #expect(signalID2.value == uuid2)
}

// MARK: - Distance and Direction Tests

@Test("Distance calculation accuracy")
func testDistanceCalculation() throws {
    let location1 = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: Date()
    )
    
    let location2 = Location(
        latitude: 37.7849, // ~1 mile north
        longitude: -122.4194,
        timestamp: Date()
    )
    
    let distance = calculateDistance(from: location1, to: location2)
    
    // Distance should be approximately 1 mile (1.6 km)
    // Using a tolerance for floating point comparison
    #expect(distance > 0.5)
    #expect(distance < 2.0)
}

@Test("Direction calculation")
func testDirectionCalculation() throws {
    let center = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: Date()
    )
    
    let north = Location(
        latitude: 37.7849, // North
        longitude: -122.4194,
        timestamp: Date()
    )
    
    let direction = calculateDirection(from: center, to: north)
    
    // Should be close to "N" (North)
    #expect(direction.contains("N"))
}

// MARK: - User Settings Tests

@Test("User settings validation")
func testUserSettingsValidation() {
    let validSettings = UserSettings(
        isOffline: false,
        distanceUnit: .mile
    )
    
    #expect(validSettings.isOffline == false)
    #expect(validSettings.distanceUnit == .mile)
    
    let offlineSettings = UserSettings(
        isOffline: true,
        distanceUnit: .kilometer
    )
    
    #expect(offlineSettings.isOffline == true)
    #expect(offlineSettings.distanceUnit == .kilometer)
}

// MARK: - Signal Status Tests

@Test("Signal status transitions")
func testSignalStatusTransitions() {
    // Test different signal statuses
    let statuses: [SignalStatus] = [.pending, .active, .expired]
    
    for status in statuses {
        let mockSignal = MockSignal(status: status)
        #expect(mockSignal.status == status)
    }
    
    // Test status equality
    #expect(SignalStatus.active == .active)
    #expect(SignalStatus.pending != .active)
}

// MARK: - Functional Programming Tests

@Test("Pure function behavior")
func testPureFunctions() throws {
    let location = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: Date()
    )
    
    // Same inputs should always produce same outputs (pure function)
    let result1 = formatLocationForDisplay(location)
    let result2 = formatLocationForDisplay(location)
    
    #expect(result1 == result2)
    #expect(result1.contains("37.7749"))
    #expect(result1.contains("-122.4194"))
}

@Test("Validation composition")
func testValidationComposition() {
    // Test that multiple validations can be composed
    let createValidUser: (String, Double, Double) throws -> (ValidatedDeviceToken, TypedCoordinate<LatitudeMarker>, TypedCoordinate<LongitudeMarker>) = { token, lat, lon in
        let validToken = try ValidatedDeviceToken.createOrThrow(token)
        let validLat = try TypedCoordinate<LatitudeMarker>.createOrThrow(lat)
        let validLon = try TypedCoordinate<LongitudeMarker>.createOrThrow(lon)
        return (validToken, validLat, validLon)
    }
    
    #expect(throws: Never.self) {
        _ = try createValidUser(
            "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0",
            37.7749,
            -122.4194
        )
    }
    
    #expect(throws: BowWowError.self) {
        _ = try createValidUser(
            "invalid", // Invalid token
            37.7749,
            -122.4194
        )
    }
}

// MARK: - Helper Functions for Testing

private func formatLocationForDisplay(_ location: Location) -> String {
    return "\(location.latitude), \(location.longitude)"
}

private func calculateDistance(from: Location, to: Location) -> Double {
    // Simplified Haversine formula for testing
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let deltaLat = (to.latitude - from.latitude) * .pi / 180
    let deltaLon = (to.longitude - from.longitude) * .pi / 180
    
    let a = sin(deltaLat/2) * sin(deltaLat/2) +
            cos(lat1) * cos(lat2) *
            sin(deltaLon/2) * sin(deltaLon/2)
    let c = 2 * atan2(sqrt(a), sqrt(1-a))
    
    return 3959 * c // Earth radius in miles
}

private func calculateDirection(from: Location, to: Location) -> String {
    let deltaLat = to.latitude - from.latitude
    let deltaLon = to.longitude - from.longitude
    
    let angle = atan2(deltaLon, deltaLat) * 180 / .pi
    let normalizedAngle = angle >= 0 ? angle : angle + 360
    
    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int((normalizedAngle + 22.5) / 45) % 8
    
    return directions[index]
}

// MARK: - Mock Types for Testing

struct MockSignal {
    let status: SignalStatus
    
    init(status: SignalStatus) {
        self.status = status
    }
}