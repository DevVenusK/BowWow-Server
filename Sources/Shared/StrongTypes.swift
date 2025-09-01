import Foundation
import Vapor

// MARK: - Phantom Types and NewType Patterns

/// Phantom Type을 위한 마커 프로토콜
public protocol PhantomType {}

/// 위도 마커
public struct LatitudeMarker: PhantomType {}
/// 경도 마커  
public struct LongitudeMarker: PhantomType {}
/// 거리 마커
public struct DistanceMarker: PhantomType {}
/// 포트 번호 마커
public struct PortMarker: PhantomType {}

/// 강타입 Coordinate - 컴파일 타임에 위도/경도 구분
public struct TypedCoordinate<Marker: PhantomType>: Codable, Equatable {
    public let value: Double
    
    public init(_ value: Double) {
        self.value = value
    }
}

/// 타입 안전한 위도/경도
public typealias Latitude = TypedCoordinate<LatitudeMarker>
public typealias Longitude = TypedCoordinate<LongitudeMarker>
public typealias Distance = TypedCoordinate<DistanceMarker>
public typealias Port = TypedCoordinate<PortMarker>

// MARK: - Validated Types

/// 검증된 값을 나타내는 강타입
public struct Validated<T, Validator: ValidationRule> where Validator.Input == T {
    public let value: T
    
    private init(value: T) {
        self.value = value
    }
    
    /// 검증된 값 생성 (실패 시 nil 반환)
    public static func create(_ input: T) -> Validated<T, Validator>? {
        guard Validator.isValid(input) else { return nil }
        return Validated(value: input)
    }
    
    /// 검증된 값 생성 (실패 시 에러 throw)
    public static func createOrThrow(_ input: T) throws -> Validated<T, Validator> {
        guard let validated = create(input) else {
            throw BowWowError.validationError(Validator.errorMessage(for: input))
        }
        return validated
    }
}

// MARK: - Validation Rules

/// 검증 규칙 프로토콜
public protocol ValidationRule {
    associatedtype Input
    static func isValid(_ input: Input) -> Bool
    static func errorMessage(for input: Input) -> String
}

/// 위도 검증 규칙 (-90 ~ 90)
public struct LatitudeValidation: ValidationRule {
    public static func isValid(_ input: Double) -> Bool {
        input >= -90.0 && input <= 90.0
    }
    
    public static func errorMessage(for input: Double) -> String {
        "Invalid latitude: \(input). Must be between -90.0 and 90.0"
    }
}

/// 경도 검증 규칙 (-180 ~ 180)
public struct LongitudeValidation: ValidationRule {
    public static func isValid(_ input: Double) -> Bool {
        input >= -180.0 && input <= 180.0
    }
    
    public static func errorMessage(for input: Double) -> String {
        "Invalid longitude: \(input). Must be between -180.0 and 180.0"
    }
}

/// 거리 검증 규칙 (0 ~ 20)
public struct DistanceValidation: ValidationRule {
    public static func isValid(_ input: Double) -> Bool {
        input >= 0.0 && input <= 20.0
    }
    
    public static func errorMessage(for input: Double) -> String {
        "Invalid distance: \(input). Must be between 0.0 and 20.0"
    }
}

/// 디바이스 토큰 검증 규칙
public struct DeviceTokenValidation: ValidationRule {
    public static func isValid(_ input: String) -> Bool {
        input.count >= 64 && input.allSatisfy { $0.isHexDigit }
    }
    
    public static func errorMessage(for input: String) -> String {
        "Invalid device token format"
    }
}

/// 강타입 검증된 값들
public typealias ValidatedLatitude = Validated<Double, LatitudeValidation>
public typealias ValidatedLongitude = Validated<Double, LongitudeValidation>
public typealias ValidatedDistance = Validated<Double, DistanceValidation>
public typealias ValidatedDeviceToken = Validated<String, DeviceTokenValidation>

// MARK: - NewType Pattern for Domain Objects

/// 강타입 사용자 ID
public struct UserID: Hashable, Codable, Content {
    public let value: UUID
    
    public init() {
        self.value = UUID()
    }
    
    public init(_ uuid: UUID) {
        self.value = uuid
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(UUID.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// 강타입 신호 ID
public struct SignalID: Hashable, Codable, Content {
    public let value: UUID
    
    public init() {
        self.value = UUID()
    }
    
    public init(_ uuid: UUID) {
        self.value = uuid
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(UUID.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// 강타입 타임스탬프
public struct SafeTimestamp: Codable, Content {
    public let value: Date
    
    public init(_ date: Date = Date()) {
        self.value = date
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Date.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Tagged Union for States

/// 신호 상태 - Tagged Union으로 각 상태에 따른 데이터 포함
public enum SignalState: Codable, Content {
    case pending(SafeTimestamp)
    case active(startedAt: SafeTimestamp, expiresAt: SafeTimestamp) 
    case expired(at: SafeTimestamp)
    case cancelled(at: SafeTimestamp, reason: String)
    
    /// 현재 상태가 활성화되어 있는지 확인
    public var isActive: Bool {
        switch self {
        case .active: return true
        default: return false
        }
    }
    
    /// 상태 변경 시간 반환
    public var timestamp: SafeTimestamp {
        switch self {
        case .pending(let time):
            return time
        case .active(let startedAt, _):
            return startedAt
        case .expired(let time):
            return time
        case .cancelled(let time, _):
            return time
        }
    }
}

/// 사용자 상태 - Tagged Union
public enum UserState: Codable, Content {
    case active(lastSeenAt: SafeTimestamp)
    case offline(since: SafeTimestamp)
    case suspended(since: SafeTimestamp, reason: String)
    
    public var isOnline: Bool {
        switch self {
        case .active: return true
        default: return false
        }
    }
}

// MARK: - Strong Location Type

/// 강타입 위치 정보
public struct StrongLocation: Codable, Content {
    public let latitude: ValidatedLatitude
    public let longitude: ValidatedLongitude
    public let timestamp: SafeTimestamp
    
    public init(latitude: ValidatedLatitude, longitude: ValidatedLongitude, timestamp: SafeTimestamp = SafeTimestamp()) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
    
    /// 안전하지 않은 값으로부터 생성 (검증 포함)
    public static func create(lat: Double, lng: Double, timestamp: Date = Date()) throws -> StrongLocation {
        let validatedLat = try ValidatedLatitude.createOrThrow(lat)
        let validatedLng = try ValidatedLongitude.createOrThrow(lng)
        return StrongLocation(
            latitude: validatedLat,
            longitude: validatedLng,
            timestamp: SafeTimestamp(timestamp)
        )
    }
}

// MARK: - Result Types with Strong Typing

/// 도메인별 에러 타입
public protocol DomainError: Error {
    var errorCode: String { get }
    var userMessage: String { get }
}

/// 위치 관련 에러
public enum LocationError: DomainError {
    case invalidCoordinates(lat: Double, lng: Double)
    case outOfBounds(location: StrongLocation)
    
    public var errorCode: String {
        switch self {
        case .invalidCoordinates: return "LOCATION_INVALID_COORDINATES"
        case .outOfBounds: return "LOCATION_OUT_OF_BOUNDS"
        }
    }
    
    public var userMessage: String {
        switch self {
        case .invalidCoordinates(let lat, let lng):
            return "Invalid coordinates: (\(lat), \(lng))"
        case .outOfBounds:
            return "Location is out of service bounds"
        }
    }
}

/// 신호 관련 에러
public enum SignalError: DomainError {
    case cooldownActive(remaining: TimeInterval)
    case userOffline(UserID)
    case invalidDistance(ValidatedDistance)
    
    public var errorCode: String {
        switch self {
        case .cooldownActive: return "SIGNAL_COOLDOWN_ACTIVE"
        case .userOffline: return "SIGNAL_USER_OFFLINE"
        case .invalidDistance: return "SIGNAL_INVALID_DISTANCE"
        }
    }
    
    public var userMessage: String {
        switch self {
        case .cooldownActive(let remaining):
            return "Signal cooldown active. Wait \(remaining) seconds."
        case .userOffline(let userID):
            return "User \(userID.value) is offline"
        case .invalidDistance(let distance):
            return "Invalid signal distance: \(distance.value)"
        }
    }
}

// MARK: - Type-Safe Builders

/// 타입 안전한 빌더 패턴
public struct SignalBuilder {
    private var senderID: UserID?
    private var location: StrongLocation?
    private var maxDistance: ValidatedDistance?
    
    public init() {}
    
    public func sender(_ id: UserID) -> SignalBuilder {
        var builder = self
        builder.senderID = id
        return builder
    }
    
    public func location(_ loc: StrongLocation) -> SignalBuilder {
        var builder = self
        builder.location = loc
        return builder
    }
    
    public func maxDistance(_ distance: ValidatedDistance) -> SignalBuilder {
        var builder = self
        builder.maxDistance = distance
        return builder
    }
    
    /// 빌드 - 필수 필드가 없으면 컴파일 타임에 오류
    public func build() throws -> StrongSignal {
        guard let senderID = senderID else {
            throw BowWowError.validationError("Sender ID is required")
        }
        guard let location = location else {
            throw BowWowError.validationError("Location is required")
        }
        
        return StrongSignal(
            id: SignalID(),
            senderID: senderID,
            location: location,
            maxDistance: maxDistance ?? (try! ValidatedDistance.createOrThrow(10.0)),
            state: .pending(SafeTimestamp()),
            createdAt: SafeTimestamp()
        )
    }
}

/// 강타입 신호 객체
public struct StrongSignal: Codable, Content {
    public let id: SignalID
    public let senderID: UserID
    public let location: StrongLocation
    public let maxDistance: ValidatedDistance
    public let state: SignalState
    public let createdAt: SafeTimestamp
    
    public init(id: SignalID, senderID: UserID, location: StrongLocation, maxDistance: ValidatedDistance, state: SignalState, createdAt: SafeTimestamp) {
        self.id = id
        self.senderID = senderID
        self.location = location
        self.maxDistance = maxDistance
        self.state = state
        self.createdAt = createdAt
    }
}

// MARK: - Extensions for Content Conformance

extension Validated: Codable where T: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let inputValue = try container.decode(T.self)
        guard let validated = Self.create(inputValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: Validator.errorMessage(for: inputValue)
                )
            )
        }
        self = validated
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension Validated: RequestDecodable where T: Content, T: Codable {
    public static func decodeRequest(_ request: Request) -> EventLoopFuture<Validated<T, Validator>> {
        return T.decodeRequest(request).flatMapThrowing { value in
            guard let validated = Validated.create(value) else {
                throw BowWowError.validationError(Validator.errorMessage(for: value))
            }
            return validated
        }
    }
}

extension Validated: ResponseEncodable where T: Content, T: Codable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        return value.encodeResponse(for: request)
    }
}

extension Validated: AsyncRequestDecodable where T: Content, T: Codable {
    public static func decodeRequest(_ request: Request) async throws -> Validated<T, Validator> {
        let value = try await T.decodeRequest(request)
        guard let validated = Validated.create(value) else {
            throw BowWowError.validationError(Validator.errorMessage(for: value))
        }
        return validated
    }
}

extension Validated: AsyncResponseEncodable where T: Content, T: Codable {
    public func encodeResponse(for request: Request) async throws -> Response {
        return try await value.encodeResponse(for: request)
    }
}

extension Validated: Content where T: Content, T: Codable {}