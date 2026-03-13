import SwiftUI
import Charts

struct SparklineView: View {
    let commitDays: [CommitDay]
    var dayCount: Int = 30
    @State private var isVisible = false

    private var recentDays: [CommitDay] {
        Array(commitDays.suffix(dayCount))
    }

    private var hasData: Bool {
        recentDays.contains { $0.count > 0 }
    }

    private var maxCommits: Int {
        recentDays.map(\.count).max() ?? 1
    }

    var body: some View {
        if !isVisible {
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(width: 200, height: 44)
                .cornerRadius(4)
                .onAppear { isVisible = true }
        } else if hasData {
            Chart(recentDays, id: \.date) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Commits", day.count)
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(1)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2]))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)")
                                .font(.system(size: 7))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .frame(width: 200, height: 44)
        } else {
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(width: 200, height: 44)
                .cornerRadius(4)
                .overlay {
                    Text("no activity")
                        .font(.system(size: 8))
                        .foregroundStyle(.quaternary)
                }
        }
    }

    private var yAxisValues: [Int] {
        if maxCommits <= 3 { return [0, maxCommits] }
        if maxCommits <= 10 { return [0, maxCommits / 2, maxCommits] }
        let step = maxCommits / 3
        return [0, step, step * 2, maxCommits]
    }
}
