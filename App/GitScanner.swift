import Foundation

actor GitScanner {
    let rootPath: String
    let maxDepth: Int
    let authorEmails: [String]
    let dayRange: Int

    init(
        rootPath: String = NSHomeDirectory() + "/Projects",
        maxDepth: Int = 5,
        authorEmails: [String] = [],
        dayRange: Int = 90
    ) {
        self.rootPath = rootPath
        self.maxDepth = maxDepth
        self.authorEmails = authorEmails
        self.dayRange = dayRange
    }

    func scanAll() async -> [RepoInfo] {
        let repoPaths = findGitRepos()
        return await withTaskGroup(of: RepoInfo?.self, returning: [RepoInfo].self) { group in
            for path in repoPaths {
                group.addTask {
                    await self.scanRepo(at: path)
                }
            }
            var results: [RepoInfo] = []
            for await result in group {
                if let repo = result {
                    results.append(repo)
                }
            }
            return results.sorted { ($0.lastCommitDate ?? .distantPast) > ($1.lastCommitDate ?? .distantPast) }
        }
    }

    func autoTagRepos(_ repos: [RepoInfo], existingTags: DomainTagStore) async -> DomainTagStore {
        let tagger = DomainAutoTagger()
        let toTag = repos.filter { existingTags.entries[$0.path]?.isManualOverride != true }

        // Run blocking git I/O on a DispatchQueue, not the Swift cooperative pool,
        // to avoid blocking cooperative threads and causing deadlocks.
        // Collect results into a Sendable array to avoid mutating actor-isolated state.
        let lock = NSLock()
        var results: [(String, RepoTagEntry)] = []
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                DispatchQueue.concurrentPerform(iterations: toTag.count) { i in
                    let repo = toTag[i]
                    let tags = tagger.autoTag(repoPath: repo.path)
                    let entry = RepoTagEntry(
                        repoPath: repo.path, tags: tags, isManualOverride: false
                    )
                    lock.lock()
                    results.append((repo.path, entry))
                    lock.unlock()
                }
                cont.resume()
            }
        }

        var updated = existingTags
        for (path, entry) in results {
            updated.entries[path] = entry
        }
        return updated
    }

    private func findGitRepos() -> [String] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)
        var repos: [String] = []

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return repos }

        let rootComponents = rootURL.standardized.pathComponents.count

        while let url = enumerator.nextObject() as? URL {
            let depth = url.standardized.pathComponents.count - rootComponents

            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            if url.lastPathComponent == ".git" {
                enumerator.skipDescendants()
                continue
            }

            let gitDir = url.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitDir.path) {
                repos.append(url.path)
                enumerator.skipDescendants()
            }
        }

        return repos
    }

    private func scanRepo(at path: String) async -> RepoInfo? {
        let sinceDate = Calendar.current.date(byAdding: .day, value: -dayRange, to: Date()) ?? Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let sinceStr = formatter.string(from: sinceDate)

        var authorArgs: [String] = []
        for email in authorEmails {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.contains("\0"), !trimmed.contains("\n") else { continue }
            authorArgs.append(contentsOf: ["--author=\(trimmed)"])
        }

        let args = ["-C", path, "log", "--format=%at", "--all", "--since=\(sinceStr)"] + authorArgs
        guard let output = runGit(args: args) else { return nil }

        let timestamps = output
            .split(separator: "\n")
            .compactMap { TimeInterval($0) }

        let commitDays = aggregateCommits(timestamps: timestamps)
        let lastCommitDate = timestamps.max().map { Date(timeIntervalSince1970: $0) }
        let name = URL(fileURLWithPath: path).lastPathComponent

        return RepoInfo(
            path: path,
            name: name,
            lastCommitDate: lastCommitDate,
            commitDays: commitDays
        )
    }

    private func aggregateCommits(timestamps: [TimeInterval]) -> [CommitDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dayCounts: [Date: Int] = [:]
        for i in 0..<dayRange {
            if let day = calendar.date(byAdding: .day, value: -i, to: today) {
                dayCounts[day] = 0
            }
        }

        for ts in timestamps {
            let date = calendar.startOfDay(for: Date(timeIntervalSince1970: ts))
            dayCounts[date, default: 0] += 1
        }

        return dayCounts
            .map { CommitDay(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private nonisolated func runGit(args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.environment = [
            "HOME": NSHomeDirectory(),
            "PATH": "/usr/bin:/bin",
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Read stdout BEFORE waitUntilExit to prevent pipe-buffer deadlock.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
