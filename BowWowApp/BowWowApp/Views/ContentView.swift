import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(NotificationManager.self) private var notificationManager
    
    @State private var selectedTab: Tab = .signal
    
    enum Tab: Hashable {
        case signal
        case settings
    }
    
    var body: some View {
        @Bindable var appStateBindable = appState
        
        TabView(selection: $selectedTab) {
            SignalMainView()
                .tabItem {
                    Label("신호", systemImage: "radio.fill")
                }
                .tag(Tab.signal)
                .badge(appState.receivedSignals.count)
            
            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .hapticSelection(trigger: selectedTab) // 커스텀 햅틱 시스템
        .alert("오류 발생", isPresented: $appStateBindable.showingError) {
            Button("확인") {
                appState.dismissError()
            }
        } message: {
            if let error = appState.lastError {
                VStack(alignment: .leading) {
                    Text(error.localizedDescription)
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                    }
                }
            }
        }
        .task {
            await setupPeriodicUpdates()
        }
    }
    
    private func setupPeriodicUpdates() async {
        // 위치 업데이트가 있을 때마다 주변 사용자와 신호 업데이트
        locationManager.onLocationUpdate = { location in
            if let strongLocation = try? StrongLocation.create(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude
            ) {
                appState.updateLocation(strongLocation)
            }
        }
        
        // 주기적으로 수신 신호 확인
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await appState.fetchReceivedSignals()
            }
        }
    }
}