import SwiftUI

struct RepoRowView: View {
    let repo: RepoInfo
    let rank: Int
    let onExclude: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Rank indicator
            Text("\(rank)")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 18)

            // Repo info
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.system(.body, weight: .semibold))
                Text(shortPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 160, alignment: .leading)

            Spacer()

            SparklineView(commitDays: repo.commitDays)

            // Commit count + time
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(repo.totalCommits)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("commits")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Text(relativeDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Button {
                openInTerminal()
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }
            Divider()
            Button(role: .destructive) {
                onExclude()
            } label: {
                Label("Exclude from List", systemImage: "eye.slash")
            }
        }
    }

    private var shortPath: String {
        repo.path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var relativeDate: String {
        guard let date = repo.lastCommitDate else { return "no commits" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func openInTerminal() {
        let escapedPath = repo.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"cd \\\"\(escapedPath)\\\"\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
