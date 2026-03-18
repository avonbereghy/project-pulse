import Foundation

struct DataStore: Sendable {
    private static let widgetBundleID = "com.avb.projectpulse.widget"

    // Main app dir (for the app's own reads)
    private static let appDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ProjectPulse")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // Widget container dir (the main app writes here so the sandboxed widget can read)
    private static let widgetDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data/Library/Application Support/ProjectPulse")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // The widget reads from its own sandboxed Application Support
    // (which is actually widgetDir above from the system's perspective)
    private static let readDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProjectPulse")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // Detect if running inside a sandbox container
    private static let isSandboxed: Bool = {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }()

    private static func readFile(_ name: String) -> URL {
        if isSandboxed {
            return readDir.appendingPathComponent(name)
        }
        return appDir.appendingPathComponent(name)
    }

    private static func writeData(_ data: Data, filename: String) throws {
        // Always write to app dir
        try data.write(to: appDir.appendingPathComponent(filename), options: .atomic)
        // Also write to widget container so the sandboxed widget can read it
        if !isSandboxed {
            try? data.write(to: widgetDir.appendingPathComponent(filename), options: .atomic)
        }
    }

    func saveRepos(_ repos: [RepoInfo]) throws {
        let data = try JSONEncoder().encode(repos)
        try Self.writeData(data, filename: "repos.json")
    }

    func loadRepos() throws -> [RepoInfo] {
        let data = try Data(contentsOf: Self.readFile("repos.json"))
        return try JSONDecoder().decode([RepoInfo].self, from: data)
    }

    func saveExclusions(_ paths: Set<String>) throws {
        let data = try JSONEncoder().encode(Array(paths))
        try Self.writeData(data, filename: "exclusions.json")
    }

    func loadExclusions() -> Set<String> {
        guard let data = try? Data(contentsOf: Self.readFile("exclusions.json")),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(paths)
    }

    func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try Self.writeData(data, filename: "settings.json")
    }

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: Self.readFile("settings.json")),
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
        try Self.writeData(data, filename: "domain-tags.json")
    }

    func loadDomainTags() -> DomainTagStore {
        guard let data = try? Data(contentsOf: Self.readFile("domain-tags.json")),
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
    var sortField: String = "7d Commits"
    var sortAscending: Bool = false
    var windowOpacity: Double = 1.0
    var showMenuBar: Bool = true
    var rescanIntervalMinutes: Int = 45
}
