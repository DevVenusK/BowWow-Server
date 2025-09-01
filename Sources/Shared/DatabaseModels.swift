import Foundation
import Vapor
import Fluent

// MARK: - Database Models

/// 사용자 데이터베이스 모델
public final class User: Model, Content {
    public static let schema = "users"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: "device_token")
    public var deviceToken: String
    
    @Field(key: "is_offline")
    public var isOffline: Bool
    
    @Field(key: "distance_unit")
    public var distanceUnit: DistanceUnit
    
    @Field(key: "created_at")
    public var createdAt: Date
    
    @Field(key: "updated_at") 
    public var updatedAt: Date
    
    public init() {}
    
    public init(id: UUID? = nil,
                deviceToken: String,
                isOffline: Bool = false,
                distanceUnit: DistanceUnit = .mile) {
        self.id = id
        self.deviceToken = deviceToken
        self.isOffline = isOffline
        self.distanceUnit = distanceUnit
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// UserID로 변환
    public func toUserID() -> UserID {
        return UserID(id ?? UUID())
    }
    
    /// UserSettings로 변환
    public func toSettings() -> UserSettings {
        return UserSettings(isOffline: isOffline, distanceUnit: distanceUnit)
    }
}

/// 사용자 위치 데이터베이스 모델 (24시간 후 자동 삭제)
public final class UserLocation: Model, Content {
    public static let schema = "user_locations"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: "user_id")
    public var user: User
    
    @Field(key: "encrypted_latitude")
    public var encryptedLatitude: String
    
    @Field(key: "encrypted_longitude")
    public var encryptedLongitude: String
    
    // PostGIS 공간 인덱스를 위한 필드 (복호화된 값은 임시로만 사용)
    @Field(key: "latitude")
    public var latitude: Double
    
    @Field(key: "longitude")
    public var longitude: Double
    
    @Field(key: "expires_at")
    public var expiresAt: Date?
    
    @Field(key: "created_at")
    public var createdAt: Date
    
    public init() {}
    
    public init(id: UUID? = nil,
                userID: UserID,
                encryptedLatitude: String,
                encryptedLongitude: String,
                latitude: Double,
                longitude: Double) {
        self.id = id
        self.$user.id = userID.value
        self.encryptedLatitude = encryptedLatitude
        self.encryptedLongitude = encryptedLongitude
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
        // 24시간 후 만료
        self.expiresAt = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
    }
}

/// 신호 데이터베이스 모델
public final class Signal: Model, Content {
    public static let schema = "signals"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: "sender_id")
    public var sender: User
    
    @Field(key: "latitude")
    public var latitude: Double
    
    @Field(key: "longitude")
    public var longitude: Double
    
    @Field(key: "max_distance")
    public var maxDistance: Int
    
    @Field(key: "status")
    public var status: SignalStatus
    
    @Field(key: "sent_at")
    public var sentAt: Date
    
    @Field(key: "expires_at")
    public var expiresAt: Date?
    
    public init() {}
    
    public init(id: UUID? = nil,
                senderID: UserID,
                latitude: Double,
                longitude: Double,
                maxDistance: Int = 10,
                status: SignalStatus = .active) {
        self.id = id
        self.$sender.id = senderID.value
        self.latitude = latitude
        self.longitude = longitude
        self.maxDistance = maxDistance
        self.status = status
        self.sentAt = Date()
        // 10분 후 만료 (신호 전파 시간)
        self.expiresAt = Calendar.current.date(byAdding: .minute, value: 10, to: Date())
    }
    
    /// Location으로 변환
    public func toLocation() -> Location {
        return Location(latitude: latitude, longitude: longitude, timestamp: sentAt)
    }
    
    /// SignalResponse로 변환
    public func toResponse() -> SignalResponse {
        return SignalResponse(
            signalID: id ?? UUID(),
            senderID: UserID($sender.id),
            sentAt: sentAt,
            maxDistance: maxDistance,
            status: status
        )
    }
}

/// 신호 수신 로그 모델
public final class SignalReceipt: Model, Content {
    public static let schema = "signal_receipts"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: "signal_id")
    public var signal: Signal
    
    @Parent(key: "receiver_id")
    public var receiver: User
    
    @Field(key: "distance")
    public var distance: Double
    
    @Field(key: "direction")
    public var direction: String
    
    @Field(key: "responded")
    public var responded: Bool
    
    @Field(key: "received_at")
    public var receivedAt: Date
    
    @Field(key: "responded_at")
    public var respondedAt: Date?
    
    public init() {}
    
    public init(id: UUID? = nil,
                signalID: UUID,
                receiverID: UserID,
                distance: Double,
                direction: String,
                responded: Bool = false) {
        self.id = id
        self.$signal.id = signalID
        self.$receiver.id = receiverID.value
        self.distance = distance
        self.direction = direction
        self.responded = responded
        self.receivedAt = Date()
    }
    
    /// ReceivedSignal로 변환
    public func toReceivedSignal() -> ReceivedSignal {
        return ReceivedSignal(
            signalID: $signal.id,
            senderID: UserID($signal.wrappedValue.sender.$id.wrappedValue ?? UUID()),
            distance: distance,
            direction: direction,
            receivedAt: receivedAt
        )
    }
}

// MARK: - Database Migrations

/// 사용자 테이블 마이그레이션
public struct CreateUser: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field("device_token", .string, .required)
            .field("is_offline", .bool, .required, .custom("DEFAULT FALSE"))
            .field("distance_unit", .string, .required, .custom("DEFAULT 'mile'"))
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "device_token")
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}

/// 사용자 위치 테이블 마이그레이션
public struct CreateUserLocation: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(UserLocation.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("encrypted_latitude", .string, .required)
            .field("encrypted_longitude", .string, .required)
            .field("latitude", .double, .required)
            .field("longitude", .double, .required)
            .field("expires_at", .datetime, .required)
            .field("created_at", .datetime, .required)
            .create()
        
        // PostGIS 공간 인덱스는 SQL 실행 시 별도로 생성
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(UserLocation.schema).delete()
    }
}

/// 신호 테이블 마이그레이션
public struct CreateSignal: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(Signal.schema)
            .id()
            .field("sender_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("latitude", .double, .required)
            .field("longitude", .double, .required)
            .field("max_distance", .int, .required, .custom("DEFAULT 10"))
            .field("status", .string, .required, .custom("DEFAULT 'active'"))
            .field("sent_at", .datetime, .required)
            .field("expires_at", .datetime, .required)
            .create()
        
        // 공간 인덱스는 SQL 실행 시 별도로 생성
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(Signal.schema).delete()
    }
}

/// 신호 수신 로그 테이블 마이그레이션
public struct CreateSignalReceipt: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(SignalReceipt.schema)
            .id()
            .field("signal_id", .uuid, .required, .references(Signal.schema, "id", onDelete: .cascade))
            .field("receiver_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("distance", .double, .required)
            .field("direction", .string, .required)
            .field("responded", .bool, .required, .custom("DEFAULT FALSE"))
            .field("received_at", .datetime, .required)
            .field("responded_at", .datetime)
            .create()
        
        // 인덱스는 SQL 실행 시 별도로 생성
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(SignalReceipt.schema).delete()
    }
}