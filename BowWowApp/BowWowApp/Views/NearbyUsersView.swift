import SwiftUI

struct NearbyUsersView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            List {
                if appState.nearbyUsers.isEmpty {
                    emptyStateView
                } else {
                    ForEach(appState.nearbyUsers, id: \.id) { user in
                        NearbyUserRow(user: user)
                    }
                }
            }
            .navigationTitle("주변 사용자")
            .refreshable {
                await appState.fetchNearbyUsers()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await appState.fetchNearbyUsers()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("주변 사용자 새로 고침")
                    .hapticLight(trigger: appState.nearbyUsers.count)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
                .accessibilityLabel("주변 사용자 없음")
            
            Text("주변에 사용자가 없습니다")
                .font(.headline)
                .foregroundStyle(.gray)
            
            Text("위치 서비스가 켜져 있는지 확인하고\n잠시 후 다시 시도해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct NearbyUserRow: View {
    let user: NearbyUserResponse
    
    var body: some View {
        HStack(spacing: 15) {
            // 방향 아이콘
            Text(user.directionEmoji)
                .font(.title2)
                .accessibilityLabel("방향 \(user.direction)")
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("사용자")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(user.distanceText)km")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                
                HStack {
                    Text(user.direction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(timeAgo(from: user.lastSeen))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 상태 표시
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .accessibilityLabel("온라인 상태")
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("주변 사용자, 거리 \(user.distanceText)킬로미터, 방향 \(user.direction), \(timeAgo(from: user.lastSeen))")
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
    NearbyUsersView()
        .environment(AppState())
}