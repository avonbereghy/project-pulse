import Foundation

struct CommitDay: Codable, Sendable {
    let date: Date
    let count: Int
}

struct RepoInfo: Codable, Identifiable, Sendable {
    var id: String { path }
    let path: String
    let name: String
    let lastCommitDate: Date?
    let commitDays: [CommitDay]

    var totalCommits: Int { commitDays.reduce(0) { $0 + $1.count } }

    var recentCommits: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return commitDays.filter { $0.date >= cutoff }.reduce(0) { $0 + $1.count }
    }
}
