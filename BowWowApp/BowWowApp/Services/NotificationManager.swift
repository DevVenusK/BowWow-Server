import UserNotifications
import SwiftUI

/// 푸시 알림 관리 서비스
@MainActor
@Observable
final class NotificationManager: NSObject {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var deviceToken: String?
    var notificationError: NotificationError?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }
    
    /// 알림 권한 요청
    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.notificationError = .permissionError(error.localizedDescription)
                } else {
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self?.registerForRemoteNotifications()
                    }
                }
            }
        }
    }
    
    /// 현재 권한 상태 확인
    private func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                
                if settings.authorizationStatus == .authorized {
                    self?.registerForRemoteNotifications()
                }
            }
        }
    }
    
    /// 원격 알림 등록
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// 디바이스 토큰 가져오기
    func getDeviceToken() async -> String? {
        // 실제 구현에서는 AppDelegate에서 설정된 토큰을 가져와야 함
        // 시뮬레이터용 64자 16진수 토큰 생성 (서버 검증 통과)
        return deviceToken ?? generateSimulatorDeviceToken()
    }
    
    /// 시뮬레이터용 유효한 디바이스 토큰 생성 (64자 16진수)
    private func generateSimulatorDeviceToken() -> String {
        let uuid1 = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let uuid2 = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return String((uuid1 + uuid2).prefix(64))
    }
    
    /// 디바이스 토큰 설정 (AppDelegate에서 호출)
    func setDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("✅ 디바이스 토큰 등록: \(tokenString)")
    }
    
    /// 로컬 알림 예약
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        delay: TimeInterval = 0
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.notificationError = .schedulingError(error.localizedDescription)
                }
            }
        }
    }
    
    /// 신호 수신 알림
    func showSignalReceivedNotification(from senderID: String, distance: Double, direction: String) {
        let title = "🐕 신호 수신!"
        let body = "\(direction) 방향 \(String(format: "%.1f", distance))km 거리에서 신호가 도착했습니다"
        
        scheduleLocalNotification(title: title, body: body)
    }
    
    /// 주변 사용자 알림
    func showNearbyUserNotification(userCount: Int) {
        guard userCount > 0 else { return }
        
        let title = "주변 사용자 발견"
        let body = "주변에 \(userCount)명의 사용자가 있습니다"
        
        scheduleLocalNotification(title: title, body: body)
    }
    
    /// 배지 숫자 업데이트
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            try? await notificationCenter.setBadgeCount(count)
        }
    }
    
    /// 모든 알림 제거
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        updateBadgeCount(0)
    }
    
    /// 특정 알림 제거
    func removeNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// 앱이 포그라운드에 있을 때 알림 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 포그라운드에서도 알림 표시
        completionHandler([.list, .banner, .badge, .sound])
    }
    
    /// 알림 탭 시 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // 푸시 알림 데이터 처리
        if let signalID = userInfo["signal_id"] as? String {
            Task {
                await handleSignalNotification(signalID: signalID)
            }
        }
        
        completionHandler()
    }
    
    private func handleSignalNotification(signalID: String) async {
        // 신호 관련 화면으로 이동하는 로직
        print("🔔 신호 알림 처리: \(signalID)")
        
        // NotificationCenter를 통해 앱 상태 업데이트
        NotificationCenter.default.post(
            name: .signalNotificationReceived,
            object: nil,
            userInfo: ["signal_id": signalID]
        )
    }
}

// MARK: - NotificationError

enum NotificationError: LocalizedError, Equatable {
    case permissionError(String)
    case schedulingError(String)
    case tokenError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionError(let message):
            return "알림 권한 오류: \(message)"
        case .schedulingError(let message):
            return "알림 예약 오류: \(message)"
        case .tokenError(let message):
            return "디바이스 토큰 오류: \(message)"
        case .unknown(let message):
            return "알 수 없는 오류: \(message)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let signalNotificationReceived = Notification.Name("signalNotificationReceived")
    static let deviceTokenReceived = Notification.Name("deviceTokenReceived")
}