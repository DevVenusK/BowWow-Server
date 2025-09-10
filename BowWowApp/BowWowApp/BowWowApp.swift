import SwiftUI
import UserNotifications
import CoreLocation
import Observation // iOS 17+

@main
@MainActor
struct BowWowApp: App {
    @State private var appState = AppState()
    @State private var locationManager = LocationManager()
    @State private var notificationManager = NotificationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(locationManager)
                .environment(notificationManager)
                .task {
                    await setupApp()
                }
        }
        #if os(iOS)
        .defaultAppStorage(.standard)
        #endif
    }
    
    private func setupApp() async {
        // 위치 권한 요청
        locationManager.requestLocationPermission()
        
        // 푸시 알림 권한 요청
        notificationManager.requestNotificationPermission()
        
        // 서버 연결 상태 확인 시작
        APIService.shared.startPeriodicHealthCheck()
        
        // 초기 연결 상태 확인
        Task {
            print("🚀 앱 시작 - 초기 서버 연결 상태 확인 중...")
            let isConnected = await APIService.shared.checkServerConnection()
            await MainActor.run {
                print("📱 메인 스레드에서 연결 상태 업데이트: \(isConnected)")
                appState.updateConnectionStatus(isConnected)
            }
        }
        
        // 연결 상태 업데이트 리스너 등록
        print("👂 NotificationCenter 리스너 등록")
        NotificationCenter.default.addObserver(
            forName: .serverConnectionStatusChanged,
            object: nil,
            queue: .main
        ) { notification in
            print("📬 NotificationCenter에서 연결 상태 알림 수신")
            if let isConnected = notification.userInfo?["isConnected"] as? Bool {
                print("📩 알림 내용: isConnected = \(isConnected)")
                Task { @MainActor in
                    appState.updateConnectionStatus(isConnected)
                }
            } else {
                print("❌ 알림에서 isConnected 값을 찾을 수 없음")
            }
        }
        
        // 디바이스 토큰으로 사용자 등록
        Task {
            await registerUser()
        }
    }
    
    private func registerUser() async {
        guard let deviceToken = await notificationManager.getDeviceToken() else {
            print("❌ 디바이스 토큰을 가져올 수 없습니다")
            return
        }
        
        do {
            let user = try await APIService.shared.registerUser(deviceToken: deviceToken)
            await MainActor.run {
                appState.currentUser = user
            }
            print("✅ 사용자 등록 완료: \(user.id)")
        } catch {
            print("❌ 사용자 등록 실패: \(error)")
        }
    }
}