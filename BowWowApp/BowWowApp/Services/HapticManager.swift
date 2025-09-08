import UIKit
import SwiftUI

/// 햅틱 피드백을 체계적으로 관리하는 매니저
@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    
    /// 가벼운 햅틱 피드백 (버튼 터치, 선택 등)
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// 중간 햅틱 피드백 (모달 표시, 탭 전환 등)
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// 강한 햅틱 피드백 (신호 전송, 중요한 액션 등)
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    // MARK: - Selection Feedback
    
    /// 선택 변경 시 햅틱 피드백 (세그먼트 컨트롤, 피커 등)
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Notification Feedback
    
    /// 성공 햅틱 피드백 (신호 전송 성공, 응답 완료 등)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// 경고 햅틱 피드백 (권한 거부, 네트워크 오류 등)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// 에러 햅틱 피드백 (신호 전송 실패, 치명적 오류 등)
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Context-Specific Methods
    
    /// 신호 전송 시 햅틱 패턴
    func signalSent() {
        heavyImpact()
        // 약간의 지연 후 성공 피드백
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.success()
        }
    }
    
    /// 신호 수신 시 햅틱 패턴
    func signalReceived() {
        mediumImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.mediumImpact()
        }
    }
    
    /// 응답 완료 시 햅틱 패턴
    func responseCompleted() {
        lightImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.success()
        }
    }
    
    /// 새로고침 완료 시 햅틱 패턴
    func refreshCompleted() {
        lightImpact()
    }
    
    /// 탭 전환 시 햅틱 패턴
    func tabChanged() {
        selectionChanged()
    }
}

// MARK: - SwiftUI Extensions

extension View {
    /// 가벼운 햅틱 피드백 추가
    func hapticLight(trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.lightImpact()
        }
    }
    
    /// 중간 햅틱 피드백 추가
    func hapticMedium(trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.mediumImpact()
        }
    }
    
    /// 강한 햅틱 피드백 추가
    func hapticHeavy(trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.heavyImpact()
        }
    }
    
    /// 선택 변경 햅틱 피드백 추가
    func hapticSelection(trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.selectionChanged()
        }
    }
    
    /// 성공 햅틱 피드백 추가
    func hapticSuccess(trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.success()
        }
    }
}