import Foundation
import Vapor
import Fluent

// MARK: - Strong Types are defined in StrongTypes.swift in the same module

// MARK: - Legacy Compatibility (Deprecated - use StrongTypes)

/// @deprecated Use StrongLocation instead
public struct Location: Codable, Content {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date
    
    @available(*, deprecated, message: "Use StrongLocation.create(lat:lng:timestamp:) instead")
    public init(latitude: Double, longitude: Double, timestamp: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
    
    /// Convert to strong type
    public func toStrongLocation() throws -> StrongLocation {
        return try StrongLocation.create(lat: latitude, lng: longitude, timestamp: timestamp)
    }
}

/// 암호화된 위치 정보
public struct EncryptedLocation: Codable, Content {
    public let encryptedData: String
    public let timestamp: Date
    
    public init(encryptedData: String, timestamp: Date = Date()) {
        self.encryptedData = encryptedData
        self.timestamp = timestamp
    }
}

/// 거리 단위 설정
public enum DistanceUnit: String, Codable, CaseIterable, Content {
    case mile = "mile"
    case kilometer = "km"
    
    public var maxDistance: Int {
        switch self {
        case .mile: return 10
        case .kilometer: return 16 // 10 mile ≈ 16km
        }
    }
}

/// 신호 상태
public enum SignalStatus: String, Codable, CaseIterable, Content {
    case pending = "pending"
    case active = "active"
    case expired = "expired"
}

/// 사용자 설정
public struct UserSettings: Codable, Content {
    public let isOffline: Bool
    public let distanceUnit: DistanceUnit
    
    public init(isOffline: Bool = false, distanceUnit: DistanceUnit = .mile) {
        self.isOffline = isOffline
        self.distanceUnit = distanceUnit
    }
}

// MARK: - Request/Response DTOs

/// 사용자 등록 요청 - Strong Typed
public struct CreateUserRequest: Codable, Content, Validatable {
    public let deviceToken: ValidatedDeviceToken
    public let settings: UserSettings?
    
    public init(deviceToken: ValidatedDeviceToken, settings: UserSettings? = nil) {
        self.deviceToken = deviceToken
        self.settings = settings
    }
    
    /// Legacy 호환성을 위한 생성자
    public static func createFromString(deviceToken: String, settings: UserSettings? = nil) throws -> CreateUserRequest {
        let validatedToken = try ValidatedDeviceToken.createOrThrow(deviceToken)
        return CreateUserRequest(deviceToken: validatedToken, settings: settings)
    }
    
    public static func validations(_ validations: inout Validations) {
        // Strong type에서 이미 검증되므로 추가 검증 불필요
    }
}

/// 사용자 등록 응답
public struct CreateUserResponse: Codable, Content {
    public let userID: UserID
    public let settings: UserSettings
    public let createdAt: Date
    
    public init(userID: UserID, settings: UserSettings, createdAt: Date = Date()) {
        self.userID = userID
        self.settings = settings
        self.createdAt = createdAt
    }
}

/// 위치 업데이트 요청 - Strong Typed
public struct LocationUpdateRequest: Codable, Content, Validatable {
    public let userID: UserID
    public let location: StrongLocation
    
    public init(userID: UserID, location: StrongLocation) {
        self.userID = userID
        self.location = location
    }
    
    /// Legacy 호환성을 위한 생성자
    public static func createFromDoubles(userID: UserID, lat: Double, lng: Double, timestamp: Date = Date()) throws -> LocationUpdateRequest {
        let strongLocation = try StrongLocation.create(lat: lat, lng: lng, timestamp: timestamp)
        return LocationUpdateRequest(userID: userID, location: strongLocation)
    }
    
    public static func validations(_ validations: inout Validations) {
        // StrongLocation에서 이미 검증되므로 추가 검증 불필요
    }
}

/// 신호 전송 요청 - Strong Typed
public struct SignalRequest: Codable, Content, Validatable {
    public let senderID: UserID
    public let location: StrongLocation
    public let maxDistance: ValidatedDistance?
    
    public init(senderID: UserID, location: StrongLocation, maxDistance: ValidatedDistance? = nil) {
        self.senderID = senderID
        self.location = location
        self.maxDistance = maxDistance
    }
    
    /// Legacy 호환성을 위한 생성자
    public static func createFromDoubles(
        senderID: UserID, 
        lat: Double, 
        lng: Double, 
        maxDistance: Double? = nil,
        timestamp: Date = Date()
    ) throws -> SignalRequest {
        let strongLocation = try StrongLocation.create(lat: lat, lng: lng, timestamp: timestamp)
        let validatedDistance = try maxDistance.map { try ValidatedDistance.createOrThrow($0) }
        return SignalRequest(senderID: senderID, location: strongLocation, maxDistance: validatedDistance)
    }
    
    public static func validations(_ validations: inout Validations) {
        // Strong types에서 이미 검증되므로 추가 검증 불필요
    }
}

/// 신호 응답
public struct SignalResponse: Codable, Content {
    public let signalID: UUID
    public let senderID: UserID
    public let sentAt: Date
    public let maxDistance: Int
    public let status: SignalStatus
    
    public init(signalID: UUID, senderID: UserID, sentAt: Date, maxDistance: Int, status: SignalStatus) {
        self.signalID = signalID
        self.senderID = senderID
        self.sentAt = sentAt
        self.maxDistance = maxDistance
        self.status = status
    }
}

/// 수신된 신호 정보
public struct ReceivedSignal: Codable, Content {
    public let signalID: UUID
    public let senderID: UserID
    public let distance: Double
    public let direction: String // "N", "NE", "E", "SE", "S", "SW", "W", "NW"
    public let receivedAt: Date
    
    public init(signalID: UUID, senderID: UserID, distance: Double, direction: String, receivedAt: Date) {
        self.signalID = signalID
        self.senderID = senderID
        self.distance = distance
        self.direction = direction
        self.receivedAt = receivedAt
    }
}

/// 푸시 알림 페이로드
public struct PushNotificationPayload: Codable, Content {
    public let deviceToken: String
    public let title: String
    public let body: String
    public let data: [String: String]?
    
    public init(deviceToken: String, title: String, body: String, data: [String: String]? = nil) {
        self.deviceToken = deviceToken
        self.title = title
        self.body = body
        self.data = data
    }
}

// MARK: - Error Types

/// 앱 도메인 에러
public enum BowWowError: Error, Codable {
    case userNotFound(UserID)
    case invalidLocation(String)
    case signalCooldown(TimeInterval)
    case userOffline(UserID)
    case encryptionFailed(String)
    case pushNotificationFailed(String)
    case databaseError(String)
    case validationError(String)
    
    public var localizedDescription: String {
        switch self {
        case .userNotFound(let userID):
            return "User not found: \(userID.value)"
        case .invalidLocation(let reason):
            return "Invalid location: \(reason)"
        case .signalCooldown(let remaining):
            return "Signal cooldown active: \(remaining) seconds remaining"
        case .userOffline(let userID):
            return "User is offline: \(userID.value)"
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .pushNotificationFailed(let reason):
            return "Push notification failed: \(reason)"
        case .databaseError(let reason):
            return "Database error: \(reason)"
        case .validationError(let reason):
            return "Validation error: \(reason)"
        }
    }
}

// MARK: - Result Types for Functional Programming

/// 함수형 프로그래밍을 위한 Result 타입 별칭
public typealias AsyncResult<T> = EventLoopFuture<Result<T, BowWowError>>
public typealias SyncResult<T> = Result<T, BowWowError>

/// 함수형 파이프라인 타입 별칭
public typealias Validator<T> = (T) -> SyncResult<T>
public typealias Transformer<A, B> = (A) -> B
public typealias AsyncAction<T, U> = (T) -> EventLoopFuture<U>
public typealias Pipeline<A, B> = (A) -> EventLoopFuture<B>