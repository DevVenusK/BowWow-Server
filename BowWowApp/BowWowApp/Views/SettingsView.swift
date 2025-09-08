import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(NotificationManager.self) private var notificationManager
    
    @State private var showingAbout = false
    @State private var animateToggle = false
    
    var body: some View {
        @Bindable var appStateBindable = appState
        
        NavigationStack {
            List {
                // 사용자 정보 섹션
                Section("사용자 정보") {
                    if let user = appState.currentUser {
                        HStack {
                            Text("사용자 ID")
                            Spacer()
                            Text(user.id?.uuidString.prefix(8) ?? "알 수 없음")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("디바이스 토큰")
                            Spacer()
                            Text(user.deviceToken.prefix(8) + "...")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("생성일")
                            Spacer()
                            Text(formatDate(user.createdAt))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    } else {
                        Text("사용자 정보를 불러오는 중...")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 앱 설정 섹션
                Section("앱 설정") {
                    HStack {
                        Label("오프라인 모드", systemImage: "airplane")
                            .symbolEffect(.pulse, value: animateToggle) // iOS 17+ symbol animation
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.userSettings.isOffline },
                            set: { newValue in
                                let settings = UserSettings(
                                    isOffline: newValue,
                                    distanceUnit: appState.userSettings.distanceUnit
                                )
                                appState.updateSettings(settings)
                                animateToggle.toggle()
                            }
                        ))
                        .hapticMedium(trigger: appState.userSettings.isOffline) // 커스텀 햅틱 시스템
                    }
                    
                    HStack {
                        Label("거리 단위", systemImage: "ruler")
                        Spacer()
                        Picker("거리 단위", selection: Binding(
                            get: { appState.userSettings.distanceUnit },
                            set: { newValue in
                                let settings = UserSettings(
                                    isOffline: appState.userSettings.isOffline,
                                    distanceUnit: newValue
                                )
                                appState.updateSettings(settings)
                            }
                        )) {
                            Text("킬로미터").tag(DistanceUnit.kilometer)
                            Text("마일").tag(DistanceUnit.mile)
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // 권한 설정 섹션
                Section("권한 설정") {
                    HStack {
                        Label("위치 서비스", systemImage: "location.fill")
                        Spacer()
                        if appState.isLocationPermissionGranted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("설정하기") {
                                openLocationSettings()
                            }
                            .font(.caption)
                        }
                    }
                    
                    HStack {
                        Label("푸시 알림", systemImage: "bell.fill")
                        Spacer()
                        if appState.isNotificationPermissionGranted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("설정하기") {
                                openNotificationSettings()
                            }
                            .font(.caption)
                        }
                    }
                }
                
                // 연결 상태 섹션
                Section("연결 상태") {
                    HStack {
                        Label("서버 연결", systemImage: "server.rack")
                        Spacer()
                        if appState.isConnectedToServer {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("연결됨")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        } else {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("연결 안됨")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    if let lastUpdate = appState.lastLocationUpdate {
                        HStack {
                            Label("마지막 위치 업데이트", systemImage: "location.circle")
                            Spacer()
                            Text(formatDateTime(lastUpdate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 개발자 정보 섹션  
                Section("앱 정보") {
                    LabeledContent("버전", value: "1.0.0")
                    LabeledContent("빌드", value: "2024.01.001")
                    
                    Button("개발자 정보") {
                        showingAbout = true
                    }
                    .sheet(isPresented: $showingAbout) {
                        AboutView()
                            .presentationDragIndicator(.visible) // iOS 16+
                            .presentationDetents([.medium, .large]) // iOS 16+
                            .presentationBackgroundInteraction(.enabled) // iOS 16.4+
                    }
                    
                    NavigationLink("오픈소스 라이선스") {
                        LicenseView()
                    }
                }
            }
            .navigationTitle("설정")
            .scrollContentBackground(.hidden) // iOS 16+ custom background
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(LocationManager())
        .environment(NotificationManager())
}