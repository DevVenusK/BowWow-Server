import Foundation
import Alamofire
import Tagged

/// BowWow 서버 API 통신 서비스 - 강타입 활용
final class APIService {
    static let shared = APIService()
    
    private let session: Session
    private let baseURL: String
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    private init() {
        // Railway에 배포된 서버 URL 사용 - API v1 경로
        self.baseURL = "https://bowwow-server-production.up.railway.app/api/v1"
        
        // 커스텀 Session 설정
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        self.session = Session(configuration: configuration)
        
        // JSON 코덱 설정
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - User Management
    
    /// 사용자 등록
    func registerUser(deviceToken: String) async throws -> User {
        let request = UserRegistrationRequest(deviceToken: deviceToken)
        
        return try await performRequest(
            method: .post,
            path: "/users/register",
            body: request,
            responseType: User.self
        )
    }
    
    /// 사용자 설정 업데이트
    func updateUserSettings(userID: UserID, settings: UserSettings) async throws -> User {
        let request = UserSettingsUpdateRequest(
            userID: userID,
            settings: settings
        )
        
        return try await performRequest(
            method: .put,
            path: "/users/\(userID.value)/settings",
            body: request,
            responseType: User.self
        )
    }
    
    // MARK: - Location Management
    
    /// 위치 업데이트
    func updateLocation(userID: UserID, location: StrongLocation) async throws {
        let request = LocationUpdateRequest(
            userID: userID,
            location: location
        )
        
        try await performRequest(
            method: .post,
            path: "/locations/update",
            body: request
        )
    }
    
    /// 주변 사용자 조회
    func getNearbyUsers(userID: UserID, distance: Double) async throws -> [NearbyUserResponse] {
        let parameters: [String: Any] = [
            "distance": distance
        ]
        
        return try await performRequest(
            method: .get,
            path: "/locations/nearby/\(userID.value)",
            parameters: parameters,
            responseType: [NearbyUserResponse].self
        )
    }
    
    // MARK: - Signal Management
    
    /// 신호 전송
    func sendSignal(senderID: UserID, location: StrongLocation, maxDistance: Int) async throws -> SignalResponse {
        let request = SendSignalRequest(
            senderID: senderID,
            latitude: location.latitude.value,
            longitude: location.longitude.value,
            maxDistance: maxDistance
        )
        
        return try await performRequest(
            method: .post,
            path: "/signals",
            body: request,
            responseType: SignalResponse.self
        )
    }
    
    /// 수신된 신호 조회
    func getReceivedSignals(userID: UserID) async throws -> [ReceivedSignal] {
        return try await performRequest(
            method: .get,
            path: "/signals/received/\(userID.value)",
            responseType: [ReceivedSignal].self
        )
    }
    
    /// 신호 응답
    func respondToSignal(signalID: UUID, userID: UserID) async throws {
        let request = SignalResponseRequest(
            signalID: signalID,
            userID: userID,
            respondedAt: Date()
        )
        
        try await performRequest(
            method: .post,
            path: "/signals/\(signalID)/respond",
            body: request
        )
    }
    
    // MARK: - Generic Request Methods
    
    private func performRequest<T: Codable>(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil,
        body: Encodable? = nil,
        responseType: T.Type
    ) async throws -> T {
        let url = baseURL + path
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Body 설정
        if let body = body {
            request.httpBody = try jsonEncoder.encode(body)
        }
        
        // Parameters 설정 (GET 요청의 경우)
        if method == .get, let parameters = parameters {
            var components = URLComponents(string: url)!
            components.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: String(describing: value))
            }
            request.url = components.url
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            return try jsonDecoder.decode(T.self, from: data)
            
        } catch let error as DecodingError {
            throw APIError.decodingError(error.localizedDescription)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    private func performRequest(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil,
        body: Encodable? = nil
    ) async throws {
        let url = baseURL + path
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Body 설정
        if let body = body {
            request.httpBody = try jsonEncoder.encode(body)
        }
        
        // Parameters 설정 (GET 요청의 경우)
        if method == .get, let parameters = parameters {
            var components = URLComponents(string: url)!
            components.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: String(describing: value))
            }
            request.url = components.url
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Request DTOs

struct UserRegistrationRequest: Codable {
    let deviceToken: String
}

struct UserSettingsUpdateRequest: Codable {
    let userID: UserID
    let settings: UserSettings
}

struct SendSignalRequest: Codable {
    let senderID: UserID
    let latitude: Double
    let longitude: Double
    let maxDistance: Int
}

struct SignalResponseRequest: Codable {
    let signalID: UUID
    let userID: UserID
    let respondedAt: Date
}

// MARK: - Response DTOs

struct NearbyUserResponse: Codable, Identifiable {
    let id: UUID
    let userID: UserID
    let distance: Double
    let direction: String
    let lastSeen: Date
    
    init(userID: UserID, distance: Double, direction: String, lastSeen: Date) {
        self.id = UUID()
        self.userID = userID
        self.distance = distance
        self.direction = direction
        self.lastSeen = lastSeen
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()  // 디코딩할 때 새로운 UUID 생성
        self.userID = try container.decode(UserID.self, forKey: .userID)
        self.distance = try container.decode(Double.self, forKey: .distance)
        self.direction = try container.decode(String.self, forKey: .direction)
        self.lastSeen = try container.decode(Date.self, forKey: .lastSeen)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userID, forKey: .userID)
        try container.encode(distance, forKey: .distance)
        try container.encode(direction, forKey: .direction)
        try container.encode(lastSeen, forKey: .lastSeen)
    }
    
    private enum CodingKeys: String, CodingKey {
        case userID, distance, direction, lastSeen
    }
    
    // MARK: - Computed Properties
    
    var distanceText: String {
        return String(format: "%.1f", distance)
    }
    
    var directionEmoji: String {
        switch direction.lowercased() {
        case let str where str.contains("북"):
            return "⬆️"
        case let str where str.contains("남"):
            return "⬇️"
        case let str where str.contains("동"):
            return "➡️"
        case let str where str.contains("서"):
            return "⬅️"
        case let str where str.contains("북동"):
            return "↗️"
        case let str where str.contains("남동"):
            return "↘️"
        case let str where str.contains("북서"):
            return "↖️"
        case let str where str.contains("남서"):
            return "↙️"
        default:
            return "📍"
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case networkError(String)
    case serverError(Int, String)
    case decodingError(String)
    case encodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다."
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .serverError(let code, let message):
            return "서버 오류 (\(code)): \(message)"
        case .decodingError(let message):
            return "데이터 파싱 오류: \(message)"
        case .encodingError(let message):
            return "데이터 인코딩 오류: \(message)"
        }
    }
}

// MARK: - Network Monitoring

extension APIService {
    /// 네트워크 연결 상태 확인
    func checkServerConnection() async -> Bool {
        do {
            let url = URL(string: baseURL + "/health")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return 200...299 ~= httpResponse.statusCode
        } catch {
            print("❌ 서버 연결 확인 실패: \(error)")
            return false
        }
    }
    
    /// 정기적인 서버 상태 확인
    func startPeriodicHealthCheck(interval: TimeInterval = 30.0) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                let isConnected = await self.checkServerConnection()
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .serverConnectionStatusChanged,
                        object: nil,
                        userInfo: ["isConnected": isConnected]
                    )
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let serverConnectionStatusChanged = Notification.Name("serverConnectionStatusChanged")
}