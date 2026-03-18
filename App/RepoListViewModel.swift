import Foundation
import SwiftUI

enum RepoSortField: String, CaseIterable {
    case totalCommits = "Total Commits"
    case recentCommits = "7d Commits"
    case lastCommit = "Last Commit"
    case name = "Name"
}

@Observable
@MainActor
final class RepoListViewModel {
    var allRepos: [RepoInfo] = [] {
        didSet { invalidateCaches() }
    }
    var excludedPaths: Set<String> = [] {
        didSet { invalidateCaches() }
    }
    var settings: AppSettings = AppSettings() {
        didSet { if oldValue.dayRange != settings.dayRange { invalidateCaches() } }
    }
    var isScanning: Bool = false
    var lastScanDate: Date? = nil
    var searchText: String = ""
    var sortField: RepoSortField = .recentCommits {
        didSet { persistSortPrefs() }
    }
    var sortAscending: Bool = false {
        didSet { persistSortPrefs() }
    }
    var domainTagStore: DomainTagStore = DomainTagStore() {
        didSet { invalidateRadarCache() }
    }

    // Cached expensive computations
    private(set) var cachedAggregateCommitDays: [CommitDay] = []
    private(set) var cachedRadarChartData: [(label: String, value: Double, repoCount: Int)] = []

    private let dataStore = DataStore()
    private var rescanTimer: Timer?
    private var isLoading = false

    var displayedRepos: [RepoInfo] {
        let filtered = allRepos.filter { !excludedPaths.contains($0.path) }
        let searched = searchText.isEmpty ? filtered : filtered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        let sorted = searched.sorted { a, b in
            let result: Bool
            switch sortField {
            case .totalCommits:
                result = a.totalCommits > b.totalCommits
            case .recentCommits:
                result = a.recentCommits > b.recentCommits
            case .lastCommit:
                result = (a.lastCommitDate ?? .distantPast) > (b.lastCommitDate ?? .distantPast)
            case .name:
                result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            return sortAscending ? !result : result
        }
        return Array(sorted.prefix(settings.displayCount))
    }

    var excludedRepos: [RepoInfo] {
        allRepos.filter { excludedPaths.contains($0.path) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var menuBarRepos: [RepoInfo] {
        let filtered = allRepos.filter { !excludedPaths.contains($0.path) }
        return Array(filtered.sorted { $0.recentCommits > $1.recentCommits }.prefix(7))
    }

    var recentTotalCommits: Int {
        allRepos.filter { !excludedPaths.contains($0.path) }
            .reduce(0) { $0 + $1.recentCommits }
    }

    var aggregateCommitDays: [CommitDay] { cachedAggregateCommitDays }

    var totalCommits: Int {
        allRepos.filter { !excludedPaths.contains($0.path) }
            .reduce(0) { $0 + $1.totalCommits }
    }

    var radarChartData: [(label: String, value: Double, repoCount: Int)] { cachedRadarChartData }

    private func invalidateCaches() {
        recomputeAggregateCommitDays()
        recomputeRadarChartData()
    }

    private func invalidateRadarCache() {
        recomputeRadarChartData()
    }

    private func recomputeAggregateCommitDays() {
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

        cachedAggregateCommitDays = merged
            .map { CommitDay(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func recomputeRadarChartData() {
        let activeRepos = allRepos.filter { !excludedPaths.contains($0.path) }
        var domainCommits: [DomainTag: (commits: Int, repos: Int)] = [:]
        for repo in activeRepos {
            guard let entry = domainTagStore.entries[repo.path] else { continue }
            for tag in entry.tags {
                let current = domainCommits[tag] ?? (0, 0)
                domainCommits[tag] = (current.commits + repo.recentCommits, current.repos + 1)
            }
        }
        cachedRadarChartData = domainCommits
            .filter { $0.value.commits > 0 }
            .map { (label: $0.key.displayName, value: Double($0.value.commits), repoCount: $0.value.repos) }
            .sorted { $0.label < $1.label }
    }

    func updateDomainTags(_ store: DomainTagStore) {
        domainTagStore = store
        try? dataStore.saveDomainTags(store)
    }

    func rerunAutoTagging() async {
        // Clear non-manual entries
        var cleared = domainTagStore
        cleared.entries = cleared.entries.filter { $0.value.isManualOverride }
        domainTagStore = cleared
        // Re-run
        let scanner = GitScanner(
            rootPath: settings.scanRoot,
            maxDepth: settings.scanDepth,
            authorEmails: settings.authorEmails,
            dayRange: settings.dayRange
        )
        let updated = await scanner.autoTagRepos(allRepos, existingTags: cleared)
        domainTagStore = updated
        try? dataStore.saveDomainTags(updated)
    }

    func load() {
        isLoading = true

        // Load all data before setting any observable properties
        let loadedSettings = dataStore.loadSettings()
        let loadedSort = RepoSortField(rawValue: loadedSettings.sortField) ?? .recentCommits
        let loadedAscending = loadedSettings.sortAscending
        let loadedExclusions = dataStore.loadExclusions()
        let loadedRepos = try? dataStore.loadRepos()
        let loadedDomainTags = dataStore.loadDomainTags()

        // Set all at once to minimize re-render cascades
        settings = loadedSettings
        sortField = loadedSort
        sortAscending = loadedAscending
        excludedPaths = loadedExclusions
        domainTagStore = loadedDomainTags

        isLoading = false

        // Defer setting allRepos so UI renders empty first, then populates
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            if let repos = loadedRepos {
                allRepos = repos
            }
            restartRescanTimer()

            // Then scan in background
            try? await Task.sleep(for: .seconds(2))
            await scan()
        }
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
        let updatedTags = await scanner.autoTagRepos(repos, existingTags: domainTagStore)
        domainTagStore = updatedTags
        try? dataStore.saveDomainTags(updatedTags)
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
        let rescanChanged = newSettings.rescanIntervalMinutes != settings.rescanIntervalMinutes
        settings = newSettings
        try? dataStore.saveSettings(newSettings)
        if rescanChanged { restartRescanTimer() }
        Task { await scan() }
    }

    private func persistSortPrefs() {
        guard !isLoading else { return }
        settings.sortField = sortField.rawValue
        settings.sortAscending = sortAscending
        try? dataStore.saveSettings(settings)
    }

    func restartRescanTimer() {
        rescanTimer?.invalidate()
        let interval = TimeInterval(settings.rescanIntervalMinutes) * 60
        rescanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.scan()
            }
        }
    }
}
