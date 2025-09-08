import SwiftUI
import Tagged
import Observation // iOS 17+

/// 앱의 전역 상태 관리 - iOS 17+ Observable macro 사용
@MainActor
@Observable
final class AppState {
    var currentUser: User?
    var userSettings: UserSettings = UserSettings(isOffline: false, distanceUnit: .mile)
    var nearbyUsers: [NearbyUserResponse] = []
    var receivedSignals: [ReceivedSignal] = []
    var isLocationPermissionGranted: Bool = false
    var isNotificationPermissionGranted: Bool = false
    var isConnectedToServer: Bool = false
    var lastLocationUpdate: Date?
    
    // MARK: - Loading States
    var isLoadingNearbyUsers: Bool = false
    var isLoadingReceivedSignals: Bool = false
    var isSendingSignal: Bool = false
    
    // MARK: - Error Handling
    var lastError: AppError?
    var showingError: Bool = false
    
    // MARK: - User Management
    
    func updateUser(_ user: User) {
        self.currentUser = user
        self.userSettings = user.toSettings()
    }
    
    func updateSettings(_ settings: UserSettings) {
        self.userSettings = settings
        
        // 서버에 설정 업데이트 전송
        Task {
            await updateUserSettingsOnServer(settings)
        }
    }
    
    private func updateUserSettingsOnServer(_ settings: UserSettings) async {
        guard let user = currentUser else { return }
        
        do {
            let updatedUser = try await APIService.shared.updateUserSettings(
                userID: user.toUserID(),
                settings: settings
            )
            self.currentUser = updatedUser
            print("✅ 사용자 설정 업데이트 완료")
        } catch {
            print("❌ 사용자 설정 업데이트 실패: \(error)")
        }
    }
    
    // MARK: - Location Management
    
    func updateLocation(_ location: StrongLocation) {
        guard let user = currentUser else { return }
        
        Task {
            do {
                try await APIService.shared.updateLocation(
                    userID: user.toUserID(),
                    location: location
                )
                self.lastLocationUpdate = Date()
                print("✅ 위치 업데이트 완료")
                
                // 주변 사용자 조회
                await fetchNearbyUsers()
            } catch {
                print("❌ 위치 업데이트 실패: \(error)")
            }
        }
    }
    
    func fetchNearbyUsers() async {
        guard let user = currentUser else { return }
        
        self.isLoadingNearbyUsers = true
        self.lastError = nil
        
        do {
            let nearby = try await APIService.shared.getNearbyUsers(
                userID: user.toUserID(),
                distance: 10.0
            )
            self.nearbyUsers = nearby
            print("✅ 주변 사용자 \(nearby.count)명 조회")
        } catch {
            self.lastError = AppError.networkError(error.localizedDescription)
            self.showingError = true
            print("❌ 주변 사용자 조회 실패: \(error)")
        }
        
        self.isLoadingNearbyUsers = false
    }
    
    // MARK: - Signal Management
    
    func sendSignal(from location: StrongLocation, maxDistance: Int = 10) async {
        guard let user = currentUser else { return }
        
        self.isSendingSignal = true
        self.lastError = nil
        
        do {
            let signalResponse = try await APIService.shared.sendSignal(
                senderID: user.toUserID(),
                location: location,
                maxDistance: maxDistance
            )
            print("✅ 신호 전송 완료: \(signalResponse.signalID)")
        } catch {
            self.lastError = AppError.signalError("신호 전송에 실패했습니다: \(error.localizedDescription)")
            self.showingError = true
            print("❌ 신호 전송 실패: \(error)")
        }
        
        self.isSendingSignal = false
    }
    
    func fetchReceivedSignals() async {
        guard let user = currentUser else { return }
        
        self.isLoadingReceivedSignals = true
        self.lastError = nil
        
        do {
            let signals = try await APIService.shared.getReceivedSignals(
                userID: user.toUserID()
            )
            self.receivedSignals = signals
            print("✅ 수신 신호 \(signals.count)개 조회")
        } catch {
            self.lastError = AppError.networkError("신호 조회에 실패했습니다: \(error.localizedDescription)")
            self.showingError = true
            print("❌ 수신 신호 조회 실패: \(error)")
        }
        
        self.isLoadingReceivedSignals = false
    }
    
    func respondToSignal(_ signalID: UUID) async {
        guard let user = currentUser else { return }
        
        do {
            try await APIService.shared.respondToSignal(
                signalID: signalID,
                userID: user.toUserID()
            )
            
            // 수신 신호 목록 새로고침
            await fetchReceivedSignals()
            print("✅ 신호 응답 완료")
        } catch {
            print("❌ 신호 응답 실패: \(error)")
        }
    }
    
    // MARK: - Connection Status
    
    func updateConnectionStatus(_ isConnected: Bool) {
        self.isConnectedToServer = isConnected
    }
    
    // MARK: - Error Management
    
    func dismissError() {
        self.showingError = false
        self.lastError = nil
    }
    
    // MARK: - Bulk Operations with Actor
    
    /// 모든 데이터를 동시에 새로고침하는 최적화된 메서드
    func refreshAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.fetchNearbyUsers()
            }
            
            group.addTask {
                await self.fetchReceivedSignals()
            }
        }
    }
}

// MARK: - Error Types

enum AppError: LocalizedError, Equatable {
    case networkError(String)
    case locationError(String)
    case signalError(String)
    case permissionDenied(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .locationError(let message):
            return "위치 오류: \(message)"
        case .signalError(let message):
            return "신호 오류: \(message)"
        case .permissionDenied(let message):
            return "권한 오류: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "네트워크 연결을 확인하고 다시 시도해주세요."
        case .locationError:
            return "위치 서비스 설정을 확인해주세요."
        case .signalError:
            return "잠시 후 다시 시도해주세요."
        case .permissionDenied:
            return "설정에서 권한을 허용해주세요."
        }
    }
}

// MARK: - Helper Models