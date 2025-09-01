import Vapor
import Fluent
import Foundation
import Shared

/// WebSocket 연결을 관리하고 실시간 위치 스트리밍을 처리하는 매니저
/// 함수형 프로그래밍 원칙을 적용한 immutable 상태 관리
public final class LocationStreamManager {
    
    // MARK: - Singleton Pattern
    
    public static let shared = LocationStreamManager()
    
    private init() {}
    
    // MARK: - Connection Management
    
    private let connectionsLock = NSLock()
    private var activeConnections: [ConnectionInfo] = []
    
    /// WebSocket 연결 정보 (Immutable)
    private struct ConnectionInfo {
        let id: UUID
        let userID: UserID
        let websocket: WebSocket
        let subscribedRadius: Double // 구독하는 반경 (km)
        let subscribedLocation: Location // 구독 중심점
        let connectedAt: Date
        
        init(userID: UserID, websocket: WebSocket, radius: Double, location: Location) {
            self.id = UUID()
            self.userID = userID
            self.websocket = websocket
            self.subscribedRadius = radius
            self.subscribedLocation = location
            self.connectedAt = Date()
        }
    }
    
    // MARK: - Public Interface
    
    /// 새로운 WebSocket 연결 추가
    public func addConnection(ws: WebSocket, req: Request) {
        ws.onText { [weak self] _, text in
            await self?.handleIncomingMessage(text: text, ws: ws, req: req)
        }
        
        ws.onClose.whenComplete { [weak self] _ in
            self?.removeConnection(ws: ws)
        }
        
        req.logger.info("📱 WebSocket connection established")
    }
    
    /// 위치 업데이트를 모든 구독자에게 브로드캐스트
    public func broadcastLocationUpdate(_ locationUpdate: LocationUpdateBroadcast) async {
        let connections = getAllConnections()
        
        await withTaskGroup(of: Void.self) { group in
            for connection in connections {
                if shouldReceiveUpdate(connection: connection, update: locationUpdate) {
                    group.addTask {
                        await self.sendLocationUpdate(to: connection, update: locationUpdate)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 수신한 메시지 처리 (순수 함수)
    private func handleIncomingMessage(text: String, ws: WebSocket, req: Request) async {
        do {
            let message = try JSONDecoder().decode(LocationStreamMessage.self, from: Data(text.utf8))
            
            switch message.type {
            case .subscribe:
                await handleSubscription(message: message, ws: ws, req: req)
            case .unsubscribe:
                removeConnection(ws: ws)
            case .ping:
                await sendPong(to: ws)
            }
            
        } catch {
            req.logger.error("📱 Failed to decode WebSocket message: \\(error)")
            await sendError(to: ws, error: "Invalid message format")
        }
    }
    
    /// 구독 요청 처리
    private func handleSubscription(message: LocationStreamMessage, ws: WebSocket, req: Request) async {
        guard let userID = message.userID,
              let latitude = message.latitude,
              let longitude = message.longitude,
              let radius = message.radius else {
            await sendError(to: ws, error: "Missing required subscription parameters")
            return
        }
        
        let location = Location(
            latitude: latitude,
            longitude: longitude,
            timestamp: Date()
        )
        
        let connectionInfo = ConnectionInfo(
            userID: userID,
            websocket: ws,
            radius: radius,
            location: location
        )
        
        addConnectionInfo(connectionInfo)
        
        req.logger.info("📱 User \\(userID.value) subscribed to location updates within \\(radius)km")
        
        // 구독 성공 응답
        let response = LocationStreamResponse(
            type: .subscriptionConfirmed,
            message: "Subscribed to location updates",
            timestamp: Date()
        )
        
        await sendResponse(to: ws, response: response)
    }
    
    /// 연결 정보를 thread-safe하게 추가
    private func addConnectionInfo(_ info: ConnectionInfo) {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        activeConnections.append(info)
    }
    
    /// WebSocket 연결 제거
    private func removeConnection(ws: WebSocket) {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        activeConnections.removeAll { $0.websocket === ws }
    }
    
    /// 모든 활성 연결 가져오기
    private func getAllConnections() -> [ConnectionInfo] {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        return Array(activeConnections)
    }
    
    /// 연결이 특정 업데이트를 받아야 하는지 판단 (순수 함수)
    private func shouldReceiveUpdate(connection: ConnectionInfo, update: LocationUpdateBroadcast) -> Bool {
        // 자신의 위치 업데이트는 제외
        guard connection.userID != update.userID else { return false }
        
        // 구독 반경 내에 있는지 확인
        let distance = calculateDistance(
            from: connection.subscribedLocation,
            to: update.location
        )
        
        return distance <= connection.subscribedRadius
    }
    
    /// 거리 계산 (순수 함수 - Haversine formula)
    private func calculateDistance(from: Location, to: Location) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLat/2) * sin(deltaLat/2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return 6371 * c // Earth radius in kilometers
    }
    
    /// 위치 업데이트를 특정 연결에 전송
    private func sendLocationUpdate(to connection: ConnectionInfo, update: LocationUpdateBroadcast) async {
        let response = LocationStreamResponse(
            type: .locationUpdate,
            userID: update.userID,
            latitude: update.location.latitude,
            longitude: update.location.longitude,
            distance: calculateDistance(from: connection.subscribedLocation, to: update.location),
            direction: calculateDirection(from: connection.subscribedLocation, to: update.location),
            timestamp: update.location.timestamp
        )
        
        await sendResponse(to: connection.websocket, response: response)
    }
    
    /// 방향 계산 (순수 함수)
    private func calculateDirection(from: Location, to: Location) -> String {
        let deltaLat = to.latitude - from.latitude
        let deltaLon = to.longitude - from.longitude
        
        let angle = atan2(deltaLon, deltaLat) * 180 / .pi
        let normalizedAngle = angle >= 0 ? angle : angle + 360
        
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((normalizedAngle + 22.5) / 45) % 8
        
        return directions[index]
    }
    
    /// Pong 응답 전송
    private func sendPong(to ws: WebSocket) async {
        let response = LocationStreamResponse(
            type: .pong,
            message: "pong",
            timestamp: Date()
        )
        
        await sendResponse(to: ws, response: response)
    }
    
    /// 에러 메시지 전송
    private func sendError(to ws: WebSocket, error: String) async {
        let response = LocationStreamResponse(
            type: .error,
            message: error,
            timestamp: Date()
        )
        
        await sendResponse(to: ws, response: response)
    }
    
    /// 응답 전송 (순수 함수)
    private func sendResponse(to ws: WebSocket, response: LocationStreamResponse) async {
        do {
            let jsonData = try JSONEncoder().encode(response)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            try await ws.send(jsonString)
        } catch {
            print("📱 Failed to send WebSocket response: \\(error)")
        }
    }
    
    // MARK: - Public Statistics
    
    /// 현재 활성 연결 수 반환
    public func getActiveConnectionCount() -> Int {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        return activeConnections.count
    }
    
    /// 특정 사용자의 연결 여부 확인
    public func isUserConnected(_ userID: UserID) -> Bool {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        return activeConnections.contains { $0.userID == userID }
    }
}

// MARK: - Message Types

/// WebSocket 수신 메시지
public struct LocationStreamMessage: Codable {
    let type: MessageType
    let userID: UserID?
    let latitude: Double?
    let longitude: Double?
    let radius: Double? // km
    
    public enum MessageType: String, Codable {
        case subscribe = "subscribe"
        case unsubscribe = "unsubscribe"  
        case ping = "ping"
    }
}

/// WebSocket 응답 메시지  
public struct LocationStreamResponse: Codable {
    let type: ResponseType
    let userID: UserID?
    let latitude: Double?
    let longitude: Double?
    let distance: Double?
    let direction: String?
    let message: String?
    let timestamp: Date
    
    public enum ResponseType: String, Codable {
        case subscriptionConfirmed = "subscription_confirmed"
        case locationUpdate = "location_update"
        case pong = "pong"
        case error = "error"
    }
    
    public init(type: ResponseType, userID: UserID? = nil, latitude: Double? = nil, longitude: Double? = nil, distance: Double? = nil, direction: String? = nil, message: String? = nil, timestamp: Date = Date()) {
        self.type = type
        self.userID = userID
        self.latitude = latitude
        self.longitude = longitude
        self.distance = distance
        self.direction = direction
        self.message = message
        self.timestamp = timestamp
    }
}

/// 위치 업데이트 브로드캐스트 데이터
public struct LocationUpdateBroadcast {
    let userID: UserID
    let location: Location
    let timestamp: Date
    
    public init(userID: UserID, location: Location, timestamp: Date = Date()) {
        self.userID = userID
        self.location = location
        self.timestamp = timestamp
    }
}