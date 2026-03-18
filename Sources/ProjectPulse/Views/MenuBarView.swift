import SwiftUI

struct MenuBarView: View {
    @Environment(RepoListViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ProjectPulse")
                    .font(.headline)
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            if viewModel.displayedRepos.isEmpty {
                Text("No repos found")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                ForEach(viewModel.displayedRepos.prefix(5)) { repo in
                    MenuBarRepoRow(repo: repo)
                }
            }

            Divider()

            HStack {
                Text("\(viewModel.totalCommits) commits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Rescan") {
                    Task { await viewModel.scan() }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(viewModel.isScanning)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 300)
    }
}

struct MenuBarRepoRow: View {
    let repo: RepoInfo

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(repo.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Text(relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(repo.totalCommits)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var relativeDate: String {
        guard let date = repo.lastCommitDate else { return "no commits" }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
