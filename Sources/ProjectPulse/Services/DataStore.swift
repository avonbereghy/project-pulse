import Foundation

struct DataStore: Sendable {
    private static let appSupportDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProjectPulse")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let reposFile = appSupportDir.appendingPathComponent("repos.json")
    private static let exclusionsFile = appSupportDir.appendingPathComponent("exclusions.json")
    private static let settingsFile = appSupportDir.appendingPathComponent("settings.json")
    private static let domainTagsFile = appSupportDir.appendingPathComponent("domain-tags.json")

    func saveRepos(_ repos: [RepoInfo]) throws {
        let data = try JSONEncoder().encode(repos)
        try data.write(to: Self.reposFile, options: .atomic)
    }

    func loadRepos() throws -> [RepoInfo] {
        let data = try Data(contentsOf: Self.reposFile)
        return try JSONDecoder().decode([RepoInfo].self, from: data)
    }

    func saveExclusions(_ paths: Set<String>) throws {
        let data = try JSONEncoder().encode(Array(paths))
        try data.write(to: Self.exclusionsFile, options: .atomic)
    }

    func loadExclusions() -> Set<String> {
        guard let data = try? Data(contentsOf: Self.exclusionsFile),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(paths)
    }

    func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try data.write(to: Self.settingsFile, options: .atomic)
    }

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: Self.settingsFile),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    // MARK: - Domain Tags (serialized as plain strings — avoids complex enum Codable)

    private struct DomainTagsJSON: Codable {
        /// repoPath → { tags: [displayName], manual: Bool }
        struct EntryJSON: Codable {
            var tags: [String]
            var manual: Bool
        }
        var entries: [String: EntryJSON]
        var customTags: [String]
    }

    func saveDomainTags(_ store: DomainTagStore) throws {
        let json = DomainTagsJSON(
            entries: store.entries.mapValues { e in
                DomainTagsJSON.EntryJSON(
                    tags: e.tags.map(\.displayName),
                    manual: e.isManualOverride
                )
            },
            customTags: store.customTags.map(\.displayName)
        )
        let data = try JSONEncoder().encode(json)
        try data.write(to: Self.domainTagsFile, options: .atomic)
    }

    func loadDomainTags() -> DomainTagStore {
        guard let data = try? Data(contentsOf: Self.domainTagsFile),
              let json = try? JSONDecoder().decode(DomainTagsJSON.self, from: data) else {
            return DomainTagStore()
        }
        let entries = Dictionary(uniqueKeysWithValues:
            json.entries.keys.map { path -> (String, RepoTagEntry) in
                let e = json.entries[path]!
                return (path, RepoTagEntry(
                    repoPath: path,
                    tags: e.tags.map { DomainTag.from(displayName: $0) },
                    isManualOverride: e.manual
                ))
            }
        )
        let customTags = json.customTags.map { DomainTag.from(displayName: $0) }
        return DomainTagStore(entries: entries, customTags: customTags)
    }
}

struct AppSettings: Codable, Sendable {
    var displayCount: Int = 10
    var dayRange: Int = 90
    var scanDepth: Int = 5
    var scanRoot: String = NSHomeDirectory() + "/Projects"
    var authorEmails: [String] = []
}
