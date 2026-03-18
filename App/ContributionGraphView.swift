import SwiftUI

struct ContributionGraphView: View {
    let commitDays: [CommitDay]

    private let columns = 13
    private let rows = 7
    private let cellSpacing: CGFloat = 3
    private let dayLabelWidth: CGFloat = 28
    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    private var maxCount: Int {
        commitDays.map(\.count).max() ?? 1
    }

    private func color(for count: Int) -> Color {
        if count == 0 { return Color.primary.opacity(0.06) }
        let intensity = min(Double(count) / max(Double(maxCount), 1.0), 1.0)
        if intensity < 0.25 { return .green.opacity(0.25) }
        if intensity < 0.5  { return .green.opacity(0.45) }
        if intensity < 0.75 { return .green.opacity(0.65) }
        return .green.opacity(0.9)
    }

    private func commitDay(week: Int, day: Int) -> CommitDay? {
        let totalCells = columns * rows
        let cellIndex = week * rows + day
        let dataIndex = commitDays.count - totalCells + cellIndex
        guard dataIndex >= 0, dataIndex < commitDays.count else { return nil }
        return commitDays[dataIndex]
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private static let tooltipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func monthLabels(cellSize: CGFloat) -> [(Int, String)] {
        var labels: [(Int, String)] = []
        let formatter = Self.monthFormatter
        var lastMonth = -1
        for week in 0..<columns {
            if let cd = commitDay(week: week, day: 0) {
                let month = Calendar.current.component(.month, from: cd.date)
                if month != lastMonth {
                    labels.append((week, formatter.string(from: cd.date)))
                    lastMonth = month
                }
            }
        }
        return labels
    }

    var body: some View {
        GeometryReader { geo in
            let hInsets: CGFloat = 32          // 16px padding each side
            let vInsets: CGFloat = 52          // 16 top + 14 month + 6 + 6 + 10 legend + 16 bottom
            let availW = geo.size.width  - hInsets - dayLabelWidth - 4
            let availH = geo.size.height - vInsets
            let cellByW = (availW - CGFloat(columns - 1) * cellSpacing) / CGFloat(columns)
            let cellByH = (availH - CGFloat(rows    - 1) * cellSpacing) / CGFloat(rows)
            let cell = max(8, min(cellByW, cellByH))

            VStack(alignment: .leading, spacing: 6) {
                // Month labels row
                HStack(spacing: 0) {
                    Color.clear.frame(width: dayLabelWidth + 4)
                    ZStack(alignment: .leading) {
                        Color.clear.frame(height: 14)
                        ForEach(monthLabels(cellSize: cell), id: \.0) { week, label in
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .offset(x: CGFloat(week) * (cell + cellSpacing))
                        }
                    }
                }

                // Day labels + grid
                HStack(alignment: .top, spacing: 4) {
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<rows, id: \.self) { day in
                            Text(dayLabels[day])
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(width: dayLabelWidth, height: cell, alignment: .trailing)
                        }
                    }

                    HStack(spacing: cellSpacing) {
                        ForEach(0..<columns, id: \.self) { week in
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<rows, id: \.self) { day in
                                    let cd = commitDay(week: week, day: day)
                                    RoundedRectangle(cornerRadius: max(2, cell * 0.2))
                                        .fill(color(for: cd?.count ?? 0))
                                        .frame(width: cell, height: cell)
                                        .help(tooltipText(for: cd))
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Legend
                HStack(spacing: 4) {
                    Spacer()
                    Text("Less").font(.system(size: 9)).foregroundStyle(.tertiary)
                    ForEach([0.0, 0.25, 0.45, 0.65, 0.9], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(opacity == 0 ? Color.primary.opacity(0.06) : .green.opacity(opacity))
                            .frame(width: 10, height: 10)
                    }
                    Text("More").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tooltipText(for cd: CommitDay?) -> String {
        guard let cd else { return "No data" }
        let dateStr = Self.tooltipDateFormatter.string(from: cd.date)
        if cd.count == 0 { return "No commits on \(dateStr)" }
        return "\(cd.count) commit\(cd.count == 1 ? "" : "s") on \(dateStr)"
    }
}
