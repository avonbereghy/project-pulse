import Foundation
import SwiftUI

@Observable
@MainActor
final class RepoListViewModel {
    var allRepos: [RepoInfo] = []
    var excludedPaths: Set<String> = []
    var settings: AppSettings = AppSettings()
    var isScanning: Bool = false
    var lastScanDate: Date? = nil
    var searchText: String = ""

    private let dataStore = DataStore()
    private var rescanTimer: Timer?

    var displayedRepos: [RepoInfo] {
        let filtered = allRepos.filter { !excludedPaths.contains($0.path) }
        let searched = searchText.isEmpty ? filtered : filtered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return Array(searched.prefix(settings.displayCount))
    }

    var excludedRepos: [RepoInfo] {
        allRepos.filter { excludedPaths.contains($0.path) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var aggregateCommitDays: [CommitDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var merged: [Date: Int] = [:]

        for i in 0..<settings.dayRange {
            if let day = calendar.date(byAdding: .day, value: -i, to: today) {
                merged[day] = 0
            }
        }

        for repo in allRepos where !excludedPaths.contains(repo.path) {
            for cd in repo.commitDays {
                let day = calendar.startOfDay(for: cd.date)
                merged[day, default: 0] += cd.count
            }
        }

        return merged
            .map { CommitDay(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }

    var totalCommits: Int {
        allRepos.filter { !excludedPaths.contains($0.path) }
            .reduce(0) { $0 + $1.totalCommits }
    }

    func load() {
        settings = dataStore.loadSettings()
        excludedPaths = dataStore.loadExclusions()

        if let cached = try? dataStore.loadRepos() {
            allRepos = cached
        }

        startRescanTimer()
        Task { await scan() }
    }

    func scan() async {
        isScanning = true

        let scanner = GitScanner(
            rootPath: settings.scanRoot,
            maxDepth: settings.scanDepth,
            authorEmails: settings.authorEmails,
            dayRange: settings.dayRange
        )

        let repos = await scanner.scanAll()
        allRepos = repos
        lastScanDate = Date()
        isScanning = false

        try? dataStore.saveRepos(repos)
    }

    func exclude(_ repo: RepoInfo) {
        excludedPaths.insert(repo.path)
        try? dataStore.saveExclusions(excludedPaths)
    }

    func include(_ repo: RepoInfo) {
        excludedPaths.remove(repo.path)
        try? dataStore.saveExclusions(excludedPaths)
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        try? dataStore.saveSettings(newSettings)
        Task { await scan() }
    }

    private func startRescanTimer() {
        rescanTimer?.invalidate()
        rescanTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.scan()
            }
        }
    }
}
