import SwiftUI
import Charts

struct SparklineView: View {
    let commitDays: [CommitDay]
    var dayCount: Int = 30

    private var recentDays: [CommitDay] {
        Array(commitDays.suffix(dayCount))
    }

    private var hasData: Bool {
        recentDays.contains { $0.count > 0 }
    }

    var body: some View {
        if hasData {
            Chart(recentDays, id: \.date) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Commits", day.count)
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(1)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: 120, height: 28)
        } else {
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(width: 120, height: 28)
                .cornerRadius(4)
                .overlay {
                    Text("no activity")
                        .font(.system(size: 8))
                        .foregroundStyle(.quaternary)
                }
        }
    }
}
