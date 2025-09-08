import XCTest
import CoreLocation
@testable import BowWowApp

final class BowWowAppTests: XCTestCase {
    
    // MARK: - 강타입 테스트
    
    func testStrongLocationCreation() {
        // 유효한 위치 좌표
        XCTAssertNoThrow(try StrongLocation.create(lat: 37.5665, lng: 126.9780))
        
        // 유효하지 않은 위도
        XCTAssertThrowsError(try StrongLocation.create(lat: 91.0, lng: 126.9780))
        XCTAssertThrowsError(try StrongLocation.create(lat: -91.0, lng: 126.9780))
        
        // 유효하지 않은 경도
        XCTAssertThrowsError(try StrongLocation.create(lat: 37.5665, lng: 181.0))
        XCTAssertThrowsError(try StrongLocation.create(lat: 37.5665, lng: -181.0))
    }
    
    func testValidatedDistanceCreation() {
        // 유효한 거리
        XCTAssertNotNil(ValidatedDistance.create(5.0))
        XCTAssertNotNil(ValidatedDistance.create(0.1))
        
        // 유효하지 않은 거리
        XCTAssertNil(ValidatedDistance.create(-1.0))
        XCTAssertNil(ValidatedDistance.create(0.0))
    }
    
    func testUserIDValidation() {
        let uuid = UUID()
        let userID = UserID(uuid)
        
        XCTAssertEqual(userID.value, uuid)
    }
    
    // MARK: - 위치 계산 테스트
    
    func testDistanceCalculation() throws {
        let seoul = try StrongLocation.create(lat: 37.5665, lng: 126.9780)
        let busan = try StrongLocation.create(lat: 35.1796, lng: 129.0756)
        
        let locationManager = LocationManager()
        let distance = locationManager.calculateDistance(from: seoul, to: busan)
        
        XCTAssertNotNil(distance)
        // 서울-부산 간 거리는 대략 325km
        XCTAssertGreaterThan(distance!.value, 320.0)
        XCTAssertLessThan(distance!.value, 330.0)
    }
    
    func testDirectionCalculation() throws {
        let center = try StrongLocation.create(lat: 37.5665, lng: 126.9780)
        let north = try StrongLocation.create(lat: 37.6, lng: 126.9780)
        let east = try StrongLocation.create(lat: 37.5665, lng: 127.0)
        
        let locationManager = LocationManager()
        
        let northDirection = locationManager.calculateDirection(from: center, to: north)
        let eastDirection = locationManager.calculateDirection(from: center, to: east)
        
        XCTAssertTrue(northDirection.contains("북"))
        XCTAssertTrue(eastDirection.contains("동"))
    }
    
    // MARK: - API 서비스 테스트
    
    func testAPIServiceURLConstruction() {
        let apiService = APIService.shared
        
        // 개발 환경에서는 localhost URL을 사용
        #if DEBUG
        XCTAssertTrue(APIService.shared.description.contains("localhost"))
        #endif
    }
    
    func testUserRegistrationRequest() {
        let deviceToken = "test_device_token_123"
        let request = UserRegistrationRequest(deviceToken: deviceToken)
        
        XCTAssertEqual(request.deviceToken, deviceToken)
    }
    
    func testSendSignalRequest() throws {
        let userID = UserID(UUID())
        let location = try StrongLocation.create(lat: 37.5665, lng: 126.9780)
        
        let request = SendSignalRequest(
            senderID: userID,
            latitude: location.latitude.value,
            longitude: location.longitude.value,
            maxDistance: 10
        )
        
        XCTAssertEqual(request.senderID, userID)
        XCTAssertEqual(request.latitude, 37.5665, accuracy: 0.0001)
        XCTAssertEqual(request.longitude, 126.9780, accuracy: 0.0001)
        XCTAssertEqual(request.maxDistance, 10)
    }
    
    // MARK: - 앱 상태 테스트
    
    @MainActor
    func testAppStateInitialization() {
        let appState = AppState()
        
        XCTAssertNil(appState.currentUser)
        XCTAssertEqual(appState.userSettings.distanceUnit, .mile)
        XCTAssertFalse(appState.userSettings.isOffline)
        XCTAssertTrue(appState.nearbyUsers.isEmpty)
        XCTAssertTrue(appState.receivedSignals.isEmpty)
        XCTAssertFalse(appState.isLocationPermissionGranted)
        XCTAssertFalse(appState.isNotificationPermissionGranted)
        XCTAssertFalse(appState.isConnectedToServer)
    }
    
    @MainActor
    func testAppStateUserUpdate() {
        let appState = AppState()
        let user = User(
            deviceToken: "test_token",
            settings: UserSettings(isOffline: true, distanceUnit: .kilometer)
        )
        
        appState.updateUser(user)
        
        XCTAssertNotNil(appState.currentUser)
        XCTAssertEqual(appState.userSettings.distanceUnit, .kilometer)
        XCTAssertTrue(appState.userSettings.isOffline)
    }
    
    // MARK: - 위치 관리자 테스트
    
    @MainActor
    func testLocationManagerInitialization() {
        let locationManager = LocationManager()
        
        XCTAssertEqual(locationManager.authorizationStatus, .notDetermined)
        XCTAssertNil(locationManager.currentLocation)
        XCTAssertNil(locationManager.locationError)
    }
    
    // MARK: - 알림 관리자 테스트
    
    @MainActor
    func testNotificationManagerInitialization() {
        let notificationManager = NotificationManager()
        
        XCTAssertEqual(notificationManager.authorizationStatus, .notDetermined)
        XCTAssertNil(notificationManager.deviceToken)
        XCTAssertNil(notificationManager.notificationError)
    }
    
    // MARK: - 성능 테스트
    
    func testStrongLocationCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = try? StrongLocation.create(
                    lat: Double.random(in: -90...90),
                    lng: Double.random(in: -180...180)
                )
            }
        }
    }
    
    func testValidatedDistanceCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = ValidatedDistance.create(Double.random(in: 0.1...100))
            }
        }
    }
}