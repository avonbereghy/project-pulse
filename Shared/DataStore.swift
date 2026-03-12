import Foundation

struct DataStore: Sendable {
    private static let sharedDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProjectPulse")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let reposFile = sharedDir.appendingPathComponent("repos.json")
    private static let exclusionsFile = sharedDir.appendingPathComponent("exclusions.json")
    private static let settingsFile = sharedDir.appendingPathComponent("settings.json")

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
}

struct AppSettings: Codable, Sendable {
    var displayCount: Int = 10
    var dayRange: Int = 90
    var scanDepth: Int = 5
    var scanRoot: String = "/Users/avb/Projects"
    var authorEmails: [String] = [
        "andy@homeperhaps.com",
        "65372380+avonbereghy@users.noreply.github.com"
    ]
}
