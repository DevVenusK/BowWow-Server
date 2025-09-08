import Foundation
import Tagged

// MARK: - Strong Types for iOS App

/// 사용자 ID 타입 - Tagged로 타입 안전성 보장
public typealias UserID = Tagged<UserIDTag, UUID>
public enum UserIDTag: Sendable {}

extension UserID {
    init(_ uuid: UUID) {
        self = UserID(rawValue: uuid)
    }
    
    /// Tagged 값에 접근하기 위한 편의 프로퍼티
    public var value: UUID {
        return self.rawValue
    }
}

/// 위치 관련 Strong Types
public typealias Latitude = Tagged<LatitudeTag, Double>
public typealias Longitude = Tagged<LongitudeTag, Double>
public enum LatitudeTag: Sendable {}
public enum LongitudeTag: Sendable {}

extension Latitude {
    public var value: Double {
        return self.rawValue
    }
}

extension Longitude {
    public var value: Double {
        return self.rawValue
    }
}

/// 강타입 위치 정보
public struct StrongLocation: Codable, Hashable, Sendable {
    public let latitude: Latitude
    public let longitude: Longitude
    public let timestamp: Date
    
    private init(latitude: Latitude, longitude: Longitude, timestamp: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
    
    /// 안전한 위치 생성 - 범위 검증 포함
    public static func create(lat: Double, lng: Double, timestamp: Date = Date()) throws -> StrongLocation {
        guard lat >= -90.0 && lat <= 90.0 else {
            throw StrongLocationError.invalidLatitude(lat)
        }
        
        guard lng >= -180.0 && lng <= 180.0 else {
            throw StrongLocationError.invalidLongitude(lng)
        }
        
        return StrongLocation(
            latitude: Latitude(rawValue: lat),
            longitude: Longitude(rawValue: lng),
            timestamp: timestamp
        )
    }
}

/// 거리 단위 설정
public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case mile = "mile"
    case kilometer = "kilometer"
    
    public var maxDistance: Int {
        switch self {
        case .mile: return 10
        case .kilometer: return 16 // 10 mile ≈ 16km
        }
    }
}

/// 사용자 설정
public struct UserSettings: Codable, Hashable, Sendable {
    public let isOffline: Bool
    public let distanceUnit: DistanceUnit
    
    public init(isOffline: Bool = false, distanceUnit: DistanceUnit = .mile) {
        self.isOffline = isOffline
        self.distanceUnit = distanceUnit
    }
}

/// 사용자 모델
public struct User: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID?
    public let deviceToken: String
    public let settings: UserSettings
    public let createdAt: Date
    
    public init(id: UUID? = nil, deviceToken: String, settings: UserSettings, createdAt: Date = Date()) {
        self.id = id
        self.deviceToken = deviceToken
        self.settings = settings
        self.createdAt = createdAt
    }
    
    /// UserID로 변환
    public func toUserID() -> UserID {
        return UserID(id ?? UUID())
    }
    
    /// UserSettings로 변환
    public func toSettings() -> UserSettings {
        return settings
    }
}

/// 수신된 신호 정보
public struct ReceivedSignal: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let signalID: UUID
    public let distance: Double
    public let direction: String
    public let receivedAt: Date
    
    public init(signalID: UUID, distance: Double, direction: String, receivedAt: Date = Date()) {
        self.id = UUID()
        self.signalID = signalID
        self.distance = distance
        self.direction = direction
        self.receivedAt = receivedAt
    }
}

/// 신호 응답 정보
public struct SignalResponse: Codable, Hashable, Sendable {
    public let signalID: UUID
    public let success: Bool
    public let message: String?
    
    public init(signalID: UUID, success: Bool, message: String? = nil) {
        self.signalID = signalID
        self.success = success
        self.message = message
    }
}

/// 위치 업데이트 요청
public struct LocationUpdateRequest: Codable {
    public let userID: UserID
    public let location: StrongLocation
    
    public init(userID: UserID, location: StrongLocation) {
        self.userID = userID
        self.location = location
    }
}

// MARK: - Validation Types

public typealias ValidatedDistance = Tagged<ValidatedDistanceTag, Double>
public enum ValidatedDistanceTag: Sendable {}

extension ValidatedDistance {
    public static func create(_ distance: Double) -> ValidatedDistance? {
        guard distance > 0.0 && distance <= 100.0 else {
            return nil
        }
        return ValidatedDistance(rawValue: distance)
    }
    
    public var value: Double {
        return self.rawValue
    }
}

// MARK: - Error Types

public enum StrongLocationError: LocalizedError {
    case invalidLatitude(Double)
    case invalidLongitude(Double)
    
    public var errorDescription: String? {
        switch self {
        case .invalidLatitude(let lat):
            return "Invalid latitude: \(lat). Must be between -90.0 and 90.0"
        case .invalidLongitude(let lng):
            return "Invalid longitude: \(lng). Must be between -180.0 and 180.0"
        }
    }
}