import Foundation

enum DomainTag: Hashable, Sendable, Identifiable {
    case nlp
    case computerVision
    case reinforcementLearning
    case audio
    case generativeAI
    case dataEngineering
    case robotics
    case appDev
    case systems
    case webDev
    case custom(String)

    var displayName: String {
        switch self {
        case .nlp: return "NLP"
        case .computerVision: return "Computer Vision"
        case .reinforcementLearning: return "Reinforcement Learning"
        case .audio: return "Audio"
        case .generativeAI: return "Generative AI"
        case .dataEngineering: return "Data Engineering"
        case .robotics: return "Robotics"
        case .appDev: return "App Dev"
        case .systems: return "Systems"
        case .webDev: return "Web Dev"
        case .custom(let name): return name
        }
    }

    var id: String { displayName }

    /// Reconstruct a DomainTag from its displayName string (used by DataStore JSON serialization).
    static func from(displayName name: String) -> DomainTag {
        switch name {
        case "NLP": return .nlp
        case "Computer Vision": return .computerVision
        case "Reinforcement Learning": return .reinforcementLearning
        case "Audio": return .audio
        case "Generative AI": return .generativeAI
        case "Data Engineering": return .dataEngineering
        case "Robotics": return .robotics
        case "App Dev": return .appDev
        case "Systems": return .systems
        case "Web Dev": return .webDev
        default: return .custom(name)
        }
    }

    static let presets: [DomainTag] = [
        .nlp, .computerVision, .reinforcementLearning, .audio, .generativeAI,
        .dataEngineering, .robotics, .appDev, .systems, .webDev
    ]
}

// MARK: - In-memory model (NOT Codable — serialized via DataStore using plain strings)

struct RepoTagEntry: Hashable, Sendable {
    var repoPath: String
    var tags: [DomainTag]
    var isManualOverride: Bool = false
}

struct DomainTagStore: Sendable {
    var entries: [String: RepoTagEntry]
    var customTags: [DomainTag]

    init(entries: [String: RepoTagEntry] = [:], customTags: [DomainTag] = []) {
        self.entries = entries
        self.customTags = customTags
    }
}
