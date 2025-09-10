import SwiftUI

struct SignalMainView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(NotificationManager.self) private var notificationManager
    
    @State private var signalDistance: Double = 10.0
    @State private var showingSignalConfirmation = false
    @State private var selectedSegment = 0 // 0: 보내기, 1: 받은 신호, 2: 주변 사용자
    @State private var scrollPosition: Int?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 세그먼트 컨트롤 - iOS 18 스타일
                Picker("", selection: $selectedSegment) {
                    Text("보내기").tag(0)
                    Text("받은 신호").tag(1)
                        .badge(appState.receivedSignals.count)
                    Text("주변").tag(2)
                        .badge(appState.nearbyUsers.count)
                }
                .pickerStyle(.segmented)
                .padding()
                .hapticSelection(trigger: selectedSegment) // 커스텀 햅틱 시스템
                
                // 선택된 뷰 표시
                switch selectedSegment {
                case 0:
                    sendSignalView
                case 1:
                    receivedSignalsView
                case 2:
                    nearbyUsersView
                default:
                    sendSignalView
                }
            }
            .navigationTitle("🐕 BowWow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    connectionStatusView
                }
            }
        }
    }
    
    // MARK: - 신호 보내기 뷰
    
    private var sendSignalView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 메인 신호 버튼
            Button(action: sendSignal) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.orange, .red]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    VStack {
                        Image(systemName: "radio.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .symbolEffect(.bounce, value: showingSignalConfirmation) // iOS 17+ symbol animation
                        
                        Text("신호 보내기")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                }
            }
            .scaleEffect(showingSignalConfirmation ? 1.1 : 1.0)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: showingSignalConfirmation) // iOS 17+ spring animation
            .disabled(!appState.isConnectedToServer || appState.currentUser == nil || appState.isSendingSignal)
            .onChange(of: showingSignalConfirmation) { _, newValue in
                if newValue {
                    HapticManager.shared.signalSent()
                }
            }
            .overlay {
                if appState.isSendingSignal {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            
            Text("주변 \(Int(signalDistance))km 범위로 신호를 보냅니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // 거리 설정 슬라이더
            VStack(spacing: 10) {
                HStack {
                    Text("신호 범위")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(signalDistance)) km")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                
                Slider(value: $signalDistance, in: 1...20, step: 1) {
                    Text("신호 범위")
                } minimumValueLabel: {
                    Text("1")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("20")
                        .font(.caption)
                }
                .tint(.orange)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
            
            // 상태 정보
            statusInfoView
        }
        .padding()
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - 받은 신호 뷰
    
    private var receivedSignalsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
            if appState.isLoadingReceivedSignals {
                ProgressView("신호 로딩 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 50)
            } else if appState.receivedSignals.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    
                    Text("받은 신호가 없습니다")
                        .font(.headline)
                        .foregroundStyle(.gray)
                    
                    Text("누군가 신호를 보내면\n여기에 표시됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 50)
            } else {
                ForEach(appState.receivedSignals, id: \.signalID) { signal in
                    SignalRow(signal: signal) {
                        respondToSignal(signal.signalID)
                    }
                    .padding(.horizontal)
                    .scrollTransition { content, phase in // iOS 17+ scroll animations
                        content
                            .opacity(phase.isIdentity ? 1 : 0.3)
                            .scaleEffect(phase.isIdentity ? 1 : 0.8)
                    }
                }
            }
            }
        }
        .refreshable {
            await appState.fetchReceivedSignals()
        }
    }
    
    // MARK: - 주변 사용자 뷰
    
    private var nearbyUsersView: some View {
        List {
            if appState.isLoadingNearbyUsers {
                ProgressView("주변 사용자 로딩 중...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .listRowBackground(Color.clear)
            } else if appState.nearbyUsers.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    
                    Text("주변에 사용자가 없습니다")
                        .font(.headline)
                        .foregroundStyle(.gray)
                    
                    Text("위치 서비스가 켜져 있는지 확인하고\n잠시 후 다시 시도해보세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .listRowBackground(Color.clear)
            } else {
                ForEach(appState.nearbyUsers, id: \.id) { user in
                    NearbyUserRow(user: user)
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await appState.fetchNearbyUsers()
        }
    }
    
    // MARK: - 공통 컴포넌트
    
    private var connectionStatusView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.isConnectedToServer ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(appState.isConnectedToServer ? "연결됨" : "연결 안됨")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusInfoView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text("위치: \(appState.isLocationPermissionGranted ? "허용" : "거부")")
                    .font(.subheadline)
                Spacer()
                if let lastUpdate = appState.lastLocationUpdate {
                    Text(formatTime(lastUpdate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.green)
                Text("알림: \(appState.isNotificationPermissionGranted ? "허용" : "거부")")
                    .font(.subheadline)
                Spacer()
            }
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.purple)
                Text("주변: \(appState.nearbyUsers.count)명")
                    .font(.subheadline)
                Spacer()
                
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.orange)
                Text("신호: \(appState.receivedSignals.count)개")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func sendSignal() {
        print("🔥 sendSignal 함수 호출됨")
        print("🔥 서버 연결: \(appState.isConnectedToServer)")
        print("🔥 사용자: \(appState.currentUser != nil ? "있음" : "없음")")
        print("🔥 신호 전송 중: \(appState.isSendingSignal)")
        print("🔥 현재 위치: \(locationManager.currentLocation != nil ? "있음" : "없음")")
        
        guard appState.isConnectedToServer else {
            print("❌ 서버에 연결되지 않음")
            return
        }
        
        guard appState.currentUser != nil else {
            print("❌ 사용자 정보가 없음")
            return
        }
        
        guard let currentLocation = locationManager.currentLocation else {
            print("❌ 현재 위치가 없음")
            return
        }
        
        print("✅ 신호 전송 시작 - 위치: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude), 거리: \(Int(signalDistance))km")
        showingSignalConfirmation = true
        
        Task {
            do {
                let strongLocation = try StrongLocation.create(
                    lat: currentLocation.coordinate.latitude,
                    lng: currentLocation.coordinate.longitude
                )
                
                print("🎯 AppState.sendSignal 호출 중...")
                await appState.sendSignal(
                    from: strongLocation,
                    maxDistance: Int(signalDistance)
                )
                
                await MainActor.run {
                    showingSignalConfirmation = false
                }
            } catch {
                await MainActor.run {
                    showingSignalConfirmation = false
                }
                print("❌ 신호 전송 중 위치 처리 오류: \(error)")
            }
        }
    }
    
    private func respondToSignal(_ signalID: UUID) {
        Task {
            await appState.respondToSignal(signalID)
            
            // 햅틱 피드백
            await MainActor.run {
                HapticManager.shared.responseCompleted()
            }
        }
    }
    
    private func refreshData() async {
        await appState.refreshAllData()
        locationManager.requestCurrentLocation()
        
        // 새로고침 완료 햅틱
        await MainActor.run {
            HapticManager.shared.refreshCompleted()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SignalMainView()
        .environment(AppState())
        .environment(LocationManager())
        .environment(NotificationManager())
}