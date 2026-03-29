import WidgetKit
import SwiftUI
import Charts

struct RepoEntry: TimelineEntry {
    let date: Date
    let repos: [RepoInfo]
    let excludedPaths: Set<String>
    let totalCommits: Int
    let commitDays: [CommitDay]
    let domainData: [(label: String, value: Double)]
}

struct Provider: TimelineProvider {
    private let dataStore = DataStore()

    func placeholder(in context: Context) -> RepoEntry {
        RepoEntry(date: Date(), repos: [], excludedPaths: [], totalCommits: 0, commitDays: [], domainData: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RepoEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RepoEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 60, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> RepoEntry {
        let repos = (try? dataStore.loadRepos()) ?? []
        let excluded = dataStore.loadExclusions()
        let settings = dataStore.loadSettings()
        let active = repos.filter { !excluded.contains($0.path) }.sorted { $0.recentCommits > $1.recentCommits }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var merged: [Date: Int] = [:]
        for i in 0..<settings.dayRange {
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

        let tagStore = dataStore.loadDomainTags()
        var domainCommits: [String: Double] = [:]
        for repo in active {
            guard let entry = tagStore.entries[repo.path] else { continue }
            for tag in entry.tags {
                domainCommits[tag.displayName, default: 0] += Double(repo.recentCommits)
            }
        }
        let domainData = domainCommits
            .filter { $0.value > 0 }
            .map { (label: $0.key, value: $0.value) }
            .sorted { $0.label < $1.label }

        return RepoEntry(
            date: Date(),
            repos: active,
            excludedPaths: excluded,
            totalCommits: active.reduce(0) { $0 + $1.recentCommits },
            commitDays: commitDays,
            domainData: domainData
        )
    }
}

// MARK: - Helpers

private let repoColors: [Color] = [.green, .blue, .orange, .cyan, .yellow, .mint, .teal, .indigo]

private func recentDays(_ days: [CommitDay], count: Int = 30) -> [CommitDay] {
    Array(days.suffix(count))
}

private func relativeDate(_ date: Date?) -> String {
    guard let date else { return "" }
    let interval = Date().timeIntervalSince(date)
    if interval < 3600 { return "\(Int(interval / 60))m" }
    if interval < 86400 { return "\(Int(interval / 3600))h" }
    return "\(Int(interval / 86400))d"
}

// MARK: - Small Widget: Daily commit line graph

struct SmallWidgetView: View {
    let entry: RepoEntry

    private var last30: [CommitDay] { recentDays(entry.commitDays) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
                Text("ProjectPulse")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.totalCommits)")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            if last30.contains(where: { $0.count > 0 }) {
                Chart(last30, id: \.date) { day in
                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Commits", day.count)
                    )
                    .foregroundStyle(.green.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Commits", day.count)
                    )
                    .foregroundStyle(.green.opacity(0.15).gradient)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.day())
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis(.hidden)
            } else {
                Spacer()
                Text("no recent activity")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }

            if let top = entry.repos.first {
                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text(top.name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Medium Widget: Top 3 repos with overlaid line graphs

struct MediumWidgetView: View {
    let entry: RepoEntry

    private var topRepos: [RepoInfo] { Array(entry.repos.prefix(6)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
                Text("ProjectPulse")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.totalCommits) commits · 7d")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if topRepos.isEmpty {
                Spacer()
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Overlaid line chart for top repos
                Chart {
                    ForEach(Array(topRepos.enumerated()), id: \.element.id) { i, repo in
                        let days = recentDays(repo.commitDays)
                        ForEach(days, id: \.date) { day in
                            LineMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Commits", day.count),
                                series: .value("Repo", repo.name)
                            )
                            .foregroundStyle(repoColors[i % repoColors.count])
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2]))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                // Legend - wrapping layout
                HStack(spacing: 6) {
                    ForEach(Array(topRepos.enumerated()), id: \.element.id) { i, repo in
                        HStack(spacing: 2) {
                            Circle()
                                .fill(repoColors[i % repoColors.count])
                                .frame(width: 4, height: 4)
                            Text(repo.name)
                                .font(.system(size: 8, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Large Widget: Per-repo line graphs

struct LargeWidgetView: View {
    let entry: RepoEntry

    private var topRepos: [RepoInfo] { Array(entry.repos.prefix(7)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                Text("ProjectPulse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.totalCommits) commits · 7d")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            if topRepos.isEmpty {
                Spacer()
                Text("Open ProjectPulse to scan repos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Individual line graph per repo
                ForEach(Array(topRepos.enumerated()), id: \.element.id) { i, repo in
                    RepoLineRow(repo: repo, color: repoColors[i % repoColors.count])
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct RepoLineRow: View {
    let repo: RepoInfo
    let color: Color

    private var last30: [CommitDay] { recentDays(repo.commitDays) }
    private var hasActivity: Bool { last30.contains { $0.count > 0 } }

    var body: some View {
        HStack(spacing: 8) {
            // Repo name + count
            VStack(alignment: .leading, spacing: 1) {
                Text(repo.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Text("\(repo.recentCommits)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(relativeDate(repo.lastCommitDate))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 80, alignment: .leading)

            // Line chart
            if hasActivity {
                Chart(last30, id: \.date) { day in
                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Commits", day.count)
                    )
                    .foregroundStyle(color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Commits", day.count)
                    )
                    .foregroundStyle(color.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 10)) { _ in
                        AxisValueLabel(format: .dateTime.day())
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.quaternary)
                            }
                        }
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.03))
                    .overlay {
                        Text("—")
                            .font(.system(size: 8))
                            .foregroundStyle(.quaternary)
                    }
            }
        }
    }
}

// MARK: - Widget Definitions

@main
struct ProjectPulseWidget: WidgetBundle {
    var body: some Widget {
        ProjectPulseSmallWidget()
        ProjectPulseMediumWidget()
        ProjectPulseLargeWidget()
        ProjectPulseRadarMediumWidget()
        ProjectPulseRadarLargeWidget()
    }
}

struct ProjectPulseSmallWidget: Widget {
    let kind = "ProjectPulseSmall"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Activity")
        .description("Commit line graph and total count")
        .supportedFamilies([.systemSmall])
    }
}

struct ProjectPulseMediumWidget: Widget {
    let kind = "ProjectPulseMedium"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Top Repos")
        .description("Overlaid line graphs for most active repos")
        .supportedFamilies([.systemMedium])
    }
}

struct ProjectPulseLargeWidget: Widget {
    let kind = "ProjectPulseLarge"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Repo Activity")
        .description("Per-repo commit line graphs")
        .supportedFamilies([.systemLarge])
    }
}

struct ProjectPulseRadarMediumWidget: Widget {
    let kind = "ProjectPulseRadarMedium"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RadarWidgetMediumView(data: entry.domainData)
        }
        .configurationDisplayName("Domain Radar")
        .description("Commit activity by ML/tech domain")
        .supportedFamilies([.systemMedium])
    }
}

struct ProjectPulseRadarLargeWidget: Widget {
    let kind = "ProjectPulseRadarLarge"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RadarWidgetLargeView(data: entry.domainData)
        }
        .configurationDisplayName("Domain Radar")
        .description("Domain focus radar with commit counts")
        .supportedFamilies([.systemLarge])
    }
}
