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