import SwiftUI

struct SignalsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            List {
                if appState.receivedSignals.isEmpty {
                    emptyStateView
                } else {
                    ForEach(appState.receivedSignals, id: \.signalID) { signal in
                        SignalRow(signal: signal) {
                            respondToSignal(signal.signalID)
                        }
                    }
                }
            }
            .navigationTitle("받은 신호")
            .refreshable {
                await appState.fetchReceivedSignals()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await appState.fetchReceivedSignals()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("신호 새로 고침")
                    .hapticLight(trigger: appState.receivedSignals.count)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
                .accessibilityLabel("받은 신호 없음")
            
            Text("받은 신호가 없습니다")
                .font(.headline)
                .foregroundStyle(.gray)
            
            Text("누군가 신호를 보내면\n여기에 표시됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func respondToSignal(_ signalID: UUID) {
        Task {
            await appState.respondToSignal(signalID)
            
            // 햅틱 피드백
            // 햅틱 피드백은 SwiftUI의 sensoryFeedback에서 처리
        }
    }
}

struct SignalRow: View {
    let signal: ReceivedSignal
    let onRespond: () -> Void
    
    @State private var hasResponded = false
    
    var body: some View {
        HStack(spacing: 15) {
            // 신호 아이콘
            ZStack {
                Circle()
                    .fill(hasResponded ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: hasResponded ? "checkmark.circle.fill" : "radio.fill")
                    .font(.title2)
                    .foregroundStyle(hasResponded ? .green : .orange)
                    .symbolEffect(.bounce, value: hasResponded)
                    .accessibilityLabel(hasResponded ? "응답 완료" : "신호 수신")
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("신호 수신")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", signal.distance))km")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                
                HStack {
                    Text(signal.direction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(timeAgo(from: signal.receivedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !hasResponded {
                Button(action: {
                    onRespond()
                    withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                        hasResponded = true
                    }
                }) {
                    Text("응답")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .accessibilityLabel("신호에 응답하기")
                .hapticMedium(trigger: hasResponded)
            } else {
                Text("응답 완료")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
        .opacity(hasResponded ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("신호 수신, 거리 \(String(format: "%.1f", signal.distance))킬로미터, 방향 \(signal.direction), \(timeAgo(from: signal.receivedAt))")
        .onAppear {
            // 이미 응답한 신호인지 확인하는 로직을 추가할 수 있음
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "방금 전"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)분 전"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)시간 전"
        } else {
            let days = Int(interval / 86400)
            return "\(days)일 전"
        }
    }
}

#Preview {
    SignalsView()
        .environment(AppState())
}