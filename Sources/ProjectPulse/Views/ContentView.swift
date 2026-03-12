import SwiftUI

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                graphSection
                repoListSection
            }
            .padding(24)
        }
        .navigationTitle("ProjectPulse")
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

    private var graphSection: some View {
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
        }
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

    private var repoListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Repos")
                    .font(.system(.headline, weight: .semibold))
                Spacer()
                if !viewModel.displayedRepos.isEmpty {
                    Text("\(viewModel.displayedRepos.count) repos")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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

    private var lastScanText: String {
        guard let date = viewModel.lastScanDate else { return "never" }
        let interval = Date().timeIntervalSince(date)
        if interval < 5 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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

    var body: some View {
        HStack(spacing: 4) {
            Text("\(label) \(value)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Stepper("", value: $value, in: 5...50, step: 5)
                .labelsHidden()
        }
    }
}
