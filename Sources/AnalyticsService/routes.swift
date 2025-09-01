import Vapor
import Fluent
import Shared

public func routes(_ app: Application) throws {
    
    // MARK: - Health Check
    app.get("health") { req -> HealthResponse in
        return HealthResponse(
            service: "AnalyticsService",
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // MARK: - Analytics Routes
    let analytics = app.grouped("analytics")
    analytics.get("stats", use: getSystemStats)
    analytics.get("signals", "activity", use: getSignalActivity)
    analytics.get("users", "activity", use: getUserActivity)
    
    app.logger.info("✅ Analytics Service routes configured")
}

// MARK: - Route Handlers

/// 시스템 통계 조회
func getSystemStats(req: Request) async throws -> SystemStats {
    // 병렬로 각 서비스의 통계 수집
    async let totalUsers = getTotalUsers(on: req.db)
    async let activeUsers = getActiveUsers(on: req.db)
    async let totalSignals = getTotalSignals(on: req.db)
    async let activeSignals = getActiveSignals(on: req.db)
    
    let stats = try await SystemStats(
        totalUsers: totalUsers,
        activeUsers: activeUsers,
        totalSignals: totalSignals,
        activeSignals: activeSignals,
        timestamp: Date()
    )
    
    return stats
}

/// 신호 활동 분석
func getSignalActivity(req: Request) async throws -> SignalActivityStats {
    let timeRange = req.query["range"] ?? "24h"
    let startDate = getStartDate(for: timeRange)
    
    // 시간대별 신호 전송 통계
    let signalsByHour = try await Signal.query(on: req.db)
        .filter(\.$sentAt > startDate)
        .all()
        .reduce(into: [Int: Int]()) { result, signal in
            let hour = Calendar.current.component(.hour, from: signal.sentAt)
            result[hour, default: 0] += 1
        }
    
    // 거리별 신호 분포
    let signalsByDistance = try await Signal.query(on: req.db)
        .filter(\.$sentAt > startDate)
        .all()
        .reduce(into: [String: Int]()) { result, signal in
            let range = getDistanceRange(signal.maxDistance)
            result[range, default: 0] += 1
        }
    
    return SignalActivityStats(
        timeRange: timeRange,
        signalsByHour: signalsByHour,
        signalsByDistance: signalsByDistance,
        totalSignals: signalsByHour.values.reduce(0, +),
        timestamp: Date()
    )
}

/// 사용자 활동 분석
func getUserActivity(req: Request) async throws -> UserActivityStats {
    let timeRange = req.query["range"] ?? "24h"
    let startDate = getStartDate(for: timeRange)
    
    // 활성 사용자 수 (위치 업데이트 기준)
    let activeUserCount = try await UserLocation.query(on: req.db)
        .filter(\.$createdAt > startDate)
        .count()
    
    // 신호 전송 사용자 수 (수동으로 중복 제거)
    let signalSenders = try await Signal.query(on: req.db)
        .filter(\.$sentAt > startDate)
        .all()
    let uniqueSenderIDs = Set(signalSenders.map { $0.$sender.id })
    let signalSenderCount = uniqueSenderIDs.count
    
    // 신호 수신 사용자 수 (수동으로 중복 제거)
    let signalReceivers = try await SignalReceipt.query(on: req.db)
        .filter(\.$receivedAt > startDate)
        .all()
    let uniqueReceiverIDs = Set(signalReceivers.map { $0.$receiver.id })
    let signalReceiverCount = uniqueReceiverIDs.count
    
    return UserActivityStats(
        timeRange: timeRange,
        activeUsers: activeUserCount,
        signalSenders: signalSenderCount,
        signalReceivers: signalReceiverCount,
        engagementRate: calculateEngagementRate(senders: signalSenderCount, receivers: signalReceiverCount, active: activeUserCount),
        timestamp: Date()
    )
}

// MARK: - Helper Functions

private func getTotalUsers(on db: Database) async throws -> Int {
    return try await User.query(on: db).count()
}

private func getActiveUsers(on db: Database) async throws -> Int {
    let oneDayAgo = Date().addingTimeInterval(-86400)
    let activeLocations = try await UserLocation.query(on: db)
        .filter(\.$createdAt > oneDayAgo)
        .all()
    let uniqueUserIDs = Set(activeLocations.map { $0.$user.id })
    return uniqueUserIDs.count
}

private func getTotalSignals(on db: Database) async throws -> Int {
    return try await Signal.query(on: db).count()
}

private func getActiveSignals(on db: Database) async throws -> Int {
    return try await Signal.query(on: db)
        .filter(\.$status == .active)
        .count()
}

private func getStartDate(for range: String) -> Date {
    let now = Date()
    switch range {
    case "1h":
        return now.addingTimeInterval(-3600)
    case "6h":
        return now.addingTimeInterval(-21600)
    case "24h":
        return now.addingTimeInterval(-86400)
    case "7d":
        return now.addingTimeInterval(-604800)
    case "30d":
        return now.addingTimeInterval(-2592000)
    default:
        return now.addingTimeInterval(-86400) // 기본 24시간
    }
}

private func getDistanceRange(_ distance: Int) -> String {
    switch distance {
    case 0...2:
        return "0-2 miles"
    case 3...5:
        return "3-5 miles"
    case 6...8:
        return "6-8 miles"
    case 9...10:
        return "9-10 miles"
    default:
        return "10+ miles"
    }
}

private func calculateEngagementRate(senders: Int, receivers: Int, active: Int) -> Double {
    guard active > 0 else { return 0.0 }
    let engaged = Set([senders, receivers]).count // 중복 제거
    return Double(engaged) / Double(active) * 100.0
}

// MARK: - Analytics Response Types

struct HealthResponse: Content {
    let service: String
    let status: String
    let timestamp: Date
    let version: String
}

struct SystemStats: Content {
    let totalUsers: Int
    let activeUsers: Int
    let totalSignals: Int
    let activeSignals: Int
    let timestamp: Date
}

struct SignalActivityStats: Content {
    let timeRange: String
    let signalsByHour: [Int: Int]
    let signalsByDistance: [String: Int]
    let totalSignals: Int
    let timestamp: Date
}

struct UserActivityStats: Content {
    let timeRange: String
    let activeUsers: Int
    let signalSenders: Int
    let signalReceivers: Int
    let engagementRate: Double
    let timestamp: Date
}