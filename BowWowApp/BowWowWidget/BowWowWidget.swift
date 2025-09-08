import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct BowWowEntry: TimelineEntry {
    let date: Date
    let nearbyUsersCount: Int
    let receivedSignalsCount: Int
    let connectionStatus: String
}

// MARK: - Widget Provider

struct BowWowProvider: TimelineProvider {
    func placeholder(in context: Context) -> BowWowEntry {
        BowWowEntry(
            date: Date(),
            nearbyUsersCount: 3,
            receivedSignalsCount: 2,
            connectionStatus: "연결됨"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BowWowEntry) -> ()) {
        let entry = BowWowEntry(
            date: Date(),
            nearbyUsersCount: 3,
            receivedSignalsCount: 2,
            connectionStatus: "연결됨"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // 실제 구현에서는 AppGroup을 통해 앱 데이터를 가져와야 함
        let currentDate = Date()
        let entry = BowWowEntry(
            date: currentDate,
            nearbyUsersCount: 0,
            receivedSignalsCount: 0,
            connectionStatus: "연결 안됨"
        )
        
        // 30분마다 업데이트
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct BowWowWidgetSmallView: View {
    var entry: BowWowEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // 앱 아이콘
            Image(systemName: "radio.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("BowWow")
                .font(.caption)
                .fontWeight(.semibold)
            
            // 상태 정보
            VStack(spacing: 2) {
                HStack {
                    Circle()
                        .fill(entry.connectionStatus == "연결됨" ? Color.green : Color.red)
                        .frame(width: 4, height: 4)
                    Text(entry.connectionStatus)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if entry.receivedSignalsCount > 0 {
                    Text("\(entry.receivedSignalsCount)개 신호")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct BowWowWidgetMediumView: View {
    var entry: BowWowEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // 왼쪽: 앱 아이콘과 이름
            VStack(spacing: 8) {
                Image(systemName: "radio.fill")
                    .font(.largeTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("BowWow")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            // 오른쪽: 상태 정보
            VStack(alignment: .leading, spacing: 12) {
                // 연결 상태
                HStack {
                    Circle()
                        .fill(entry.connectionStatus == "연결됨" ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(entry.connectionStatus)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // 주변 사용자
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    Text("\(entry.nearbyUsersCount)명")
                        .font(.subheadline)
                }
                
                // 받은 신호
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                        .frame(width: 16)
                    Text("\(entry.receivedSignalsCount)개")
                        .font(.subheadline)
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct BowWowWidgetLargeView: View {
    var entry: BowWowEntry
    
    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                Image(systemName: "radio.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("BowWow")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 연결 상태
                HStack {
                    Circle()
                        .fill(entry.connectionStatus == "연결됨" ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(entry.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 통계 카드들
            HStack(spacing: 12) {
                // 주변 사용자 카드
                StatCard(
                    icon: "person.2.fill",
                    count: entry.nearbyUsersCount,
                    label: "주변 사용자",
                    color: .blue
                )
                
                // 받은 신호 카드
                StatCard(
                    icon: "bell.fill",
                    count: entry.receivedSignalsCount,
                    label: "받은 신호",
                    color: .orange
                )
            }
            
            // 빠른 액션
            Text("앱을 열어 신호를 보내보세요")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct StatCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Widget Entry View

struct BowWowWidgetEntryView: View {
    var entry: BowWowProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            BowWowWidgetSmallView(entry: entry)
        case .systemMedium:
            BowWowWidgetMediumView(entry: entry)
        case .systemLarge:
            BowWowWidgetLargeView(entry: entry)
        default:
            BowWowWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct BowWowWidget: Widget {
    let kind: String = "BowWowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BowWowProvider()) { entry in
            BowWowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("BowWow")
        .description("위치 기반 신호 서비스의 상태를 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    BowWowWidget()
} timeline: {
    BowWowEntry(date: .now, nearbyUsersCount: 3, receivedSignalsCount: 2, connectionStatus: "연결됨")
    BowWowEntry(date: .now, nearbyUsersCount: 1, receivedSignalsCount: 5, connectionStatus: "연결됨")
}

#Preview(as: .systemMedium) {
    BowWowWidget()
} timeline: {
    BowWowEntry(date: .now, nearbyUsersCount: 3, receivedSignalsCount: 2, connectionStatus: "연결됨")
}

#Preview(as: .systemLarge) {
    BowWowWidget()
} timeline: {
    BowWowEntry(date: .now, nearbyUsersCount: 3, receivedSignalsCount: 2, connectionStatus: "연결됨")
}