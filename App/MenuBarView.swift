import SwiftUI
import Charts

struct MenuBarView: View {
    @Environment(RepoListViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("ProjectPulse")
                    .font(.system(.headline, weight: .bold))
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Text("\(viewModel.totalCommits) commits")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, 8)

            // Repo list with charts
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.displayedRepos.isEmpty {
                        Text("No repos found")
                            .foregroundStyle(.secondary)
                            .padding(20)
                    } else {
                        ForEach(viewModel.displayedRepos.prefix(7)) { repo in
                            MenuBarRepoRow(repo: repo)
                            if repo.id != viewModel.displayedRepos.prefix(7).last?.id {
                                Divider()
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 420)

            Divider()
                .padding(.horizontal, 8)

            // Footer
            HStack {
                Button("Rescan") {
                    Task { await viewModel.scan() }
                }
                .buttonStyle(.borderless)
                .font(.system(.caption, weight: .medium))
                .disabled(viewModel.isScanning)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.red.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 340)
    }
}

struct MenuBarRepoRow: View {
    let repo: RepoInfo

    private var recentDays: [CommitDay] {
        Array(repo.commitDays.suffix(30))
    }

    private var hasActivity: Bool {
        recentDays.contains { $0.count > 0 }
    }

    private var maxCount: Int {
        recentDays.map(\.count).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Repo name + stats
            HStack(alignment: .firstTextBaseline) {
                Text(repo.name)
                    .font(.system(.body, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Text("\(repo.totalCommits)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
                Text("commits")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Text("·")
                    .foregroundStyle(.quaternary)

                Text(relativeDate)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            // Mini chart with axes
            if hasActivity {
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
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2]))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .font(.system(size: 8))
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
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(.primary.opacity(0.02))
                }
                .frame(height: 44)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.03))
                    .frame(height: 28)
                    .overlay {
                        Text("no recent activity")
                            .font(.system(size: 8))
                            .foregroundStyle(.quaternary)
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
        }
    }

    private var relativeDate: String {
        guard let date = repo.lastCommitDate else { return "no commits" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var yAxisValues: [Int] {
        if maxCount <= 3 { return [0, maxCount] }
        if maxCount <= 10 { return [0, maxCount / 2, maxCount] }
        let step = maxCount / 3
        return [0, step, step * 2, maxCount]
    }
}
