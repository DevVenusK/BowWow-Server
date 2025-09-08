import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAnimation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // 앱 아이콘 및 타이틀
                    VStack(spacing: 20) {
                        Image(systemName: "radio.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.bounce.up, value: showAnimation) // iOS 17+
                            .onAppear {
                                showAnimation = true
                            }
                        
                        Text("BowWow")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("위치 기반 신호 서비스")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // 앱 설명
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "location.circle.fill",
                            title: "실시간 위치 공유",
                            description: "주변 사용자들과 안전하게 위치를 공유합니다"
                        )
                        
                        FeatureRow(
                            icon: "bell.badge.fill",
                            title: "즉각적인 신호 전송",
                            description: "필요한 순간 빠르게 신호를 보낼 수 있습니다"
                        )
                        
                        FeatureRow(
                            icon: "lock.shield.fill",
                            title: "프라이버시 보호",
                            description: "모든 위치 데이터는 암호화되어 안전하게 보관됩니다"
                        )
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 개발 정보
                    VStack(spacing: 12) {
                        Text("Made with ❤️ in Seoul")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("© 2024 BowWow Team")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("BowWow 소개")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    AboutView()
}