import WidgetKit
import SwiftUI

struct RepoEntry: TimelineEntry {
    let date: Date
    let repos: [RepoInfo]
    let excludedPaths: Set<String>
    let totalCommits: Int
    let commitDays: [CommitDay]
}

struct Provider: TimelineProvider {
    private let dataStore = DataStore()

    func placeholder(in context: Context) -> RepoEntry {
        RepoEntry(
            date: Date(),
            repos: [],
            excludedPaths: [],
            totalCommits: 0,
            commitDays: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RepoEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RepoEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> RepoEntry {
        let repos = (try? dataStore.loadRepos()) ?? []
        let excluded = dataStore.loadExclusions()
        let active = repos.filter { !excluded.contains($0.path) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var merged: [Date: Int] = [:]
        for i in 0..<90 {
            if let day = calendar.date(byAdding: .day, value: -i, to: today) {
                merged[day] = 0
            }
        }
        for repo in active {
            for cd in repo.commitDays {
                let day = calendar.startOfDay(for: cd.date)
                merged[day, default: 0] += cd.count
            }
        }
        let commitDays = merged
            .map { CommitDay(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }

        let totalCommits = active.reduce(0) { $0 + $1.totalCommits }

        return RepoEntry(
            date: Date(),
            repos: active,
            excludedPaths: excluded,
            totalCommits: totalCommits,
            commitDays: commitDays
        )
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: RepoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                Text("ProjectPulse")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.totalCommits)")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("commits (90d)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer()

            if let top = entry.repos.first {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(top.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: RepoEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: stats
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                    Text("ProjectPulse")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text("\(entry.totalCommits)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("commits (90d)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(entry.repos.filter { $0.totalCommits > 0 }.count) active repos")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Right: top repos
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(entry.repos.prefix(4).enumerated()), id: \.element.id) { i, repo in
                    HStack(spacing: 6) {
                        Text("\(i + 1)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(width: 12)
                        Text(repo.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(repo.totalCommits)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if entry.repos.isEmpty {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: RepoEntry

    private let gridColumns = 13
    private let gridRows = 7
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2

    private var maxCount: Int {
        entry.commitDays.map(\.count).max() ?? 1
    }

    private func color(for count: Int) -> Color {
        if count == 0 { return Color.primary.opacity(0.06) }
        let intensity = min(Double(count) / max(Double(maxCount), 1.0), 1.0)
        if intensity < 0.25 { return .green.opacity(0.25) }
        if intensity < 0.5 { return .green.opacity(0.45) }
        if intensity < 0.75 { return .green.opacity(0.65) }
        return .green.opacity(0.9)
    }

    private func commitDay(week: Int, day: Int) -> CommitDay? {
        let totalCells = gridColumns * gridRows
        let cellIndex = week * gridRows + day
        let dataIndex = entry.commitDays.count - totalCells + cellIndex
        guard dataIndex >= 0, dataIndex < entry.commitDays.count else { return nil }
        return entry.commitDays[dataIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                Text("ProjectPulse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.totalCommits) commits")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }

            // Mini contribution graph
            HStack(spacing: cellSpacing) {
                ForEach(0..<gridColumns, id: \.self) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<gridRows, id: \.self) { day in
                            let cd = commitDay(week: week, day: day)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(color(for: cd?.count ?? 0))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()

            // Repo list
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(entry.repos.prefix(6).enumerated()), id: \.element.id) { i, repo in
                    HStack(spacing: 8) {
                        Text("\(i + 1)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                        Text(repo.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(repo.totalCommits)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                        Text(relativeDate(repo.lastCommitDate))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            if entry.repos.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Open ProjectPulse to scan repos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}

// MARK: - Widget Definition

@main
struct ProjectPulseWidget: WidgetBundle {
    var body: some Widget {
        ProjectPulseSmallWidget()
        ProjectPulseMediumWidget()
        ProjectPulseLargeWidget()
    }
}

struct ProjectPulseSmallWidget: Widget {
    let kind = "ProjectPulseSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Commit Count")
        .description("Total commits and most active repo")
        .supportedFamilies([.systemSmall])
    }
}

struct ProjectPulseMediumWidget: Widget {
    let kind = "ProjectPulseMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Active Repos")
        .description("Top repos with commit counts")
        .supportedFamilies([.systemMedium])
    }
}

struct ProjectPulseLargeWidget: Widget {
    let kind = "ProjectPulseLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Contribution Graph")
        .description("Commit activity heatmap and top repos")
        .supportedFamilies([.systemLarge])
    }
}
