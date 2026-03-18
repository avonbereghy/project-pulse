import SwiftUI
import Charts

enum SidebarItem: String, Hashable {
    case dashboard
    case settings
}

struct ContentView: View {
    @Environment(RepoListViewModel.self) private var viewModel
    @State private var selection: SidebarItem = .dashboard

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                        .tag(SidebarItem.dashboard)
                    Label("Settings", systemImage: "gear")
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            Group {
                switch selection {
                case .dashboard:
                    DashboardView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $vm.searchText, prompt: "Filter repos")
        .onAppear { viewModel.load() }
    }
}

struct DashboardView: View {
    @Environment(RepoListViewModel.self) private var viewModel
    @State private var chartsReady = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                if chartsReady {
                    graphSection
                } else {
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.primary.opacity(0.04))
                            .frame(height: 180)
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary.opacity(0.04))
                                .frame(height: 200)
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary.opacity(0.04))
                                .frame(height: 200)
                        }
                    }
                }
                repoListSection
            }
            .padding(24)
        }
        .navigationTitle("ProjectPulse")
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            chartsReady = true
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    StepperControl(value: Binding(
                        get: { viewModel.settings.displayCount },
                        set: { viewModel.settings.displayCount = $0 }
                    ), label: "Show")

                    Button {
                        Task { await viewModel.scan() }
                    } label: {
                        if viewModel.isScanning {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isScanning)
                    .help("Rescan repos")
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "number",
                title: "Total Commits",
                value: "\(viewModel.totalCommits)",
                subtitle: "last \(viewModel.settings.dayRange) days",
                accent: .green
            )
            StatCard(
                icon: "folder.fill",
                title: "Active Repos",
                value: "\(viewModel.displayedRepos.filter { $0.totalCommits > 0 }.count)",
                subtitle: "of \(viewModel.allRepos.count) found",
                accent: .blue
            )
            StatCard(
                icon: "clock",
                title: "Last Scan",
                value: lastScanText,
                subtitle: viewModel.isScanning ? "scanning..." : "",
                accent: .orange
            )
        }
    }

    private static let repoColors: [Color] = [.green, .blue, .orange, .cyan, .yellow, .mint, .teal, .indigo]

    private var graphSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left column: Repo Activity + Contribution Activity stacked
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Repo Activity")
                            .font(.system(.headline, weight: .semibold))
                        Spacer()
                        Text("\(viewModel.totalCommits) commits")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                    repoLineChart
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    repoLegend
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Contribution Activity")
                            .font(.system(.headline, weight: .semibold))
                        Spacer()
                        Text("\(viewModel.settings.dayRange) days")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                    ContributionGraphView(commitDays: viewModel.aggregateCommitDays)
                        .frame(height: 200)
                }
                .cardStyle()
            }
            .frame(maxWidth: .infinity)

            // Right column: Domain Focus full height
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Domain Focus")
                        .font(.system(.headline, weight: .semibold))
                    Spacer()
                    Text("\(viewModel.settings.dayRange)d")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)

                RadarChartView(data: viewModel.radarChartData)
                    .frame(maxHeight: 340)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .cardStyle()
        }
    }

    private var topReposForChart: [RepoInfo] {
        Array(viewModel.displayedRepos.filter { $0.totalCommits > 0 }.prefix(8))
    }

    private var repoLineChart: some View {
        Chart {
            ForEach(Array(topReposForChart.enumerated()), id: \.element.id) { i, repo in
                let days = Array(repo.commitDays.suffix(30))
                ForEach(days, id: \.date) { day in
                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Commits", day.count),
                        series: .value("Repo", repo.name)
                    )
                    .foregroundStyle(Self.repoColors[i % Self.repoColors.count].opacity(viewModel.settings.windowOpacity))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2]))
                    .foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 10))
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
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 140)
    }

    private var repoLegend: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(topReposForChart.enumerated()), id: \.element.id) { i, repo in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Self.repoColors[i % Self.repoColors.count])
                        .frame(width: 6, height: 6)
                    Text(repo.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
        }
    }

    private var radarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Domain Focus")
                    .font(.system(.headline, weight: .semibold))
                Spacer()
                Text("\(viewModel.settings.dayRange) days")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            RadarChartView(data: viewModel.radarChartData)
                .frame(height: 380)
                .padding(16)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var repoListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Repos")
                    .font(.system(.headline, weight: .semibold))
                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        ForEach(RepoSortField.allCases, id: \.self) { field in
                            Button {
                                viewModel.sortField = field
                            } label: {
                                HStack {
                                    Text(field.rawValue)
                                    if field == viewModel.sortField {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                            Text(viewModel.sortField.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button {
                        viewModel.sortAscending.toggle()
                    } label: {
                        Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(viewModel.sortAscending ? "Ascending" : "Descending")

                    if !viewModel.displayedRepos.isEmpty {
                        Text("\(viewModel.displayedRepos.count) repos")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if viewModel.displayedRepos.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No repos found")
                            .foregroundStyle(.secondary)
                    }
                    .padding(40)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.displayedRepos.enumerated()), id: \.element.id) { index, repo in
                        RepoRowView(repo: repo, rank: index + 1) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                viewModel.exclude(repo)
                            }
                        }
                        .padding(.horizontal, 12)

                        if index < viewModel.displayedRepos.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .cardStyle()
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var lastScanText: String {
        guard let date = viewModel.lastScanDate else { return "never" }
        let interval = Date().timeIntervalSince(date)
        if interval < 5 { return "just now" }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.7))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct StepperControl: View {
    @Binding var value: Int
    let label: String

    private let options = [5, 10, 15, 20, 30, 50]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { n in
                Button {
                    value = n
                } label: {
                    HStack {
                        Text("\(n) repos")
                        if n == value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("\(label) \(value)")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Card Style

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalSize: CGSize = .zero

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalSize.width = max(totalSize.width, x - spacing)
        }
        totalSize.height = y + rowHeight
        return (totalSize, positions)
    }
}
