import Vapor
import Fluent
import Crypto
import Shared

public func routes(_ app: Application) throws {
    
    // MARK: - Health Check
    app.get("health") { req -> HealthResponse in
        return HealthResponse(
            service: "LocationService",
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // MARK: - Location Routes
    let locations = app.grouped("locations")
    locations.post("update", use: updateLocation)
    locations.get("nearby", ":userID", use: getNearbyUsers)
    
    app.logger.info("✅ Location Service routes configured")
}

// MARK: - Route Handlers

/// 위치 업데이트 - Strong Typed with Encryption
func updateLocation(req: Request) async throws -> Response {
    let locationRequest = try req.content.decode(LocationUpdateRequest.self)
    
    // 사용자 존재 확인
    let userExists = try await User.find(locationRequest.userID.value, on: req.db) != nil
    guard userExists else {
        throw Abort(.notFound, reason: "User not found")
    }
    
    // TODO: [CRYPTO-001] 프로덕션 환경용 안전한 암호화 키 관리 시스템 구현 필요
    // TODO: [CRYPTO-002] LOCATION_ENCRYPTION_KEY 환경 변수 설정 및 검증 추가
    // TODO: [CRYPTO-003] 키 순환(Key Rotation) 정책 구현 필요
    // TODO: [CRYPTO-004] AWS KMS, HashiCorp Vault 등 외부 키 관리 서비스 연동 고려
    // 위치 데이터 암호화 - AES-GCM 256비트 사용
    let encryptionKey = getOrCreateEncryptionKey(from: req.application.environment)
    let encryptedLat = try encryptLocationValue(locationRequest.location.latitude.value, key: encryptionKey)
    let encryptedLng = try encryptLocationValue(locationRequest.location.longitude.value, key: encryptionKey)
    
    req.logger.info("🔐 Location encrypted for user: \(locationRequest.userID.value)")
    
    // 기존 위치 삭제 (24시간 만료 정책)
    try await UserLocation.query(on: req.db)
        .filter(\.$user.$id == locationRequest.userID.value)
        .delete()
    
    // 새 위치 저장
    let userLocation = UserLocation(
        userID: locationRequest.userID,
        encryptedLatitude: encryptedLat,
        encryptedLongitude: encryptedLng,
        latitude: locationRequest.location.latitude.value, // PostGIS 공간 인덱스용
        longitude: locationRequest.location.longitude.value
    )
    
    try await userLocation.save(on: req.db)
    
    // 실시간 위치 업데이트 브로드캐스트
    let legacyLocation = Location(
        latitude: locationRequest.location.latitude.value,
        longitude: locationRequest.location.longitude.value,
        timestamp: locationRequest.location.timestamp.value
    )
    
    let broadcast = LocationUpdateBroadcast(
        userID: locationRequest.userID,
        location: legacyLocation
    )
    
    await LocationStreamManager.shared.broadcastLocationUpdate(broadcast)
    
    req.logger.info("Location updated for user: \(locationRequest.userID.value)")
    return Response(status: .ok)
}

/// 주변 사용자 조회 - Strong Typed with Distance Calculation
func getNearbyUsers(req: Request) async throws -> [NearbyUser] {
    guard let userIDParam = req.parameters.get("userID", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid user ID")
    }
    
    let userID = UserID(userIDParam)
    let maxDistance = req.query["distance"] ?? "10.0"
    
    guard let distanceValue = Double(maxDistance),
          let validatedDistance = ValidatedDistance.create(distanceValue) else {
        throw Abort(.badRequest, reason: "Invalid distance parameter")
    }
    
    // 현재 사용자 위치 조회
    guard let currentUserLocation = try await UserLocation.query(on: req.db)
        .filter(\.$user.$id == userID.value)
        .first() else {
        throw Abort(.notFound, reason: "User location not found")
    }
    
    // PostGIS 공간 쿼리로 주변 사용자 검색 (강타입 거리로 제한)
    let nearbyLocations = try await UserLocation.query(on: req.db)
        .filter(\.$user.$id != userID.value)
        .filter(\.$expiresAt > Date()) // 만료되지 않은 위치만
        .all()
    
    let currentLocation = try StrongLocation.create(
        lat: currentUserLocation.latitude,
        lng: currentUserLocation.longitude
    )
    
    // 함수형 파이프라인으로 주변 사용자 필터링
    let nearbyUsers = try nearbyLocations.compactMap { location -> NearbyUser? in
        do {
            let targetLocation = try StrongLocation.create(
                lat: location.latitude,
                lng: location.longitude
            )
            
            let distance = calculateDistance(from: currentLocation, to: targetLocation)
            
            // 강타입 거리 검증
            guard distance.value <= validatedDistance.value else { return nil }
            
            let direction = calculateDirection(from: currentLocation, to: targetLocation)
            
            return NearbyUser(
                userID: UserID(location.$user.id),
                distance: distance.value,
                direction: direction,
                lastSeen: location.createdAt
            )
        } catch {
            req.logger.error("Failed to process location: \\(error)")
            return nil
        }
    }
    
    return nearbyUsers.sorted { $0.distance < $1.distance }
}

// MARK: - Encryption Helpers - AES-GCM 256

/// 환경에서 암호화 키를 가져오거나 생성
private func getOrCreateEncryptionKey(from environment: Environment) -> SymmetricKey {
    if let keyString = Environment.get("LOCATION_ENCRYPTION_KEY") {
        // 환경 변수에서 키 로드 (Base64 인코딩된 32바이트)
        if let keyData = Data(base64Encoded: keyString), keyData.count == 32 {
            return SymmetricKey(data: keyData)
        }
    }
    
    // 새로운 키 생성 (프로덕션에서는 안전한 키 관리 시스템 사용)
    let newKey = SymmetricKey(size: .bits256)
    let keyData = newKey.withUnsafeBytes { Data($0) }
    let keyString = keyData.base64EncodedString()
    
    print("⚠️  Generated new encryption key (store this securely):")
    print("   LOCATION_ENCRYPTION_KEY=\\(keyString)")
    
    return newKey
}

/// 위치 값을 AES-GCM으로 암호화
private func encryptLocationValue(_ value: Double, key: SymmetricKey) throws -> String {
    // 위치 값을 문자열로 변환 (높은 정밀도 유지)
    let valueString = String(format: "%.10f", value)
    let valueData = Data(valueString.utf8)
    
    // AES-GCM으로 암호화
    let sealedBox = try AES.GCM.seal(valueData, using: key)
    
    // 암호화된 데이터를 Base64로 인코딩
    guard let combinedData = sealedBox.combined else {
        throw BowWowError.encryptionFailed("Failed to get combined encrypted data")
    }
    
    return combinedData.base64EncodedString()
}

/// 암호화된 위치 값을 복호화
private func decryptLocationValue(_ encryptedValue: String, key: SymmetricKey) throws -> Double {
    // Base64 디코딩
    guard let combinedData = Data(base64Encoded: encryptedValue) else {
        throw BowWowError.encryptionFailed("Invalid base64 encrypted data")
    }
    
    // AES-GCM SealedBox 생성
    let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
    
    // 복호화
    let decryptedData = try AES.GCM.open(sealedBox, using: key)
    
    // Double로 변환
    guard let valueString = String(data: decryptedData, encoding: .utf8),
          let value = Double(valueString) else {
        throw BowWowError.encryptionFailed("Failed to parse decrypted location value")
    }
    
    return value
}

/// 위치 데이터 무결성 검증
private func validateEncryptedLocation(_ encryptedLat: String, _ encryptedLng: String, key: SymmetricKey) -> Bool {
    do {
        let lat = try decryptLocationValue(encryptedLat, key: key)
        let lng = try decryptLocationValue(encryptedLng, key: key)
        
        // 위도/경도 범위 검증
        return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0
    } catch {
        return false
    }
}

// MARK: - Response Types

struct HealthResponse: Content {
    let service: String
    let status: String
    let timestamp: Date
    let version: String
}

struct NearbyUser: Content {
    let userID: UserID
    let distance: Double
    let direction: String
    let lastSeen: Date
}