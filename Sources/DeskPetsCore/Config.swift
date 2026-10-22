import Foundation

/// A pet bound to a session. The session is remembered by pid + start time, and by provider + cwd
/// so the pet re-attaches when the session restarts with a new pid.
public struct PetBinding: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var provider: Provider
    public var cwd: String
    public var character: String
    public var pid: Int32?
    public var pidStart: Double?
    public var x: Double?
    public var y: Double?

    public init(id: UUID = UUID(), provider: Provider, cwd: String, character: String,
                pid: Int32? = nil, pidStart: Double? = nil, x: Double? = nil, y: Double? = nil) {
        self.id = id
        self.provider = provider
        self.cwd = cwd
        self.character = character
        self.pid = pid
        self.pidStart = pidStart
        self.x = x
        self.y = y
    }

    public func matchesExactly(_ session: AgentSession) -> Bool {
        guard let pid, let pidStart else { return false }
        return session.provider == provider && session.pid == pid && abs(session.startTime - pidStart) < 2
    }
}

public struct AppConfig: Codable, Equatable, Sendable {
    public static let sizes = [64, 96, 128]
    public static let animationDurationRange = 0.4...6.0

    public var showPets = true
    public var petSize = 96
    public var animationDuration: Double?
    public var bindings: [PetBinding] = []

    public init(showPets: Bool = true, petSize: Int = 96, bindings: [PetBinding] = [],
                animationDuration: Double? = nil) {
        self.showPets = showPets
        self.petSize = petSize
        self.bindings = bindings
        self.animationDuration = animationDuration.flatMap { Self.animationDurationRange.contains($0) ? $0 : nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showPets = try container.decodeIfPresent(Bool.self, forKey: .showPets) ?? true
        petSize = try container.decodeIfPresent(Int.self, forKey: .petSize) ?? 96
        bindings = try container.decodeIfPresent([PetBinding].self, forKey: .bindings) ?? []
        animationDuration = (try? container.decodeIfPresent(Double.self, forKey: .animationDuration))
            .flatMap { Self.animationDurationRange.contains($0) ? $0 : nil }
    }

    /// Missing or unreadable config yields defaults; a broken file is never fatal.
    public static func load(from url: URL) -> AppConfig {
        guard let data = try? Data(contentsOf: url) else { return AppConfig() }
        return (try? JSONDecoder().decode(AppConfig.self, from: data)) ?? AppConfig()
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

public enum BindingResolver {
    /// Pairs bindings with live sessions: exact pid match first, then same provider + cwd
    /// (oldest session first). Re-attached bindings get the new pid written back.
    /// Returns binding id → session id.
    public static func resolve(_ bindings: inout [PetBinding], sessions: [AgentSession]) -> [UUID: String] {
        var result: [UUID: String] = [:]
        var used = Set<String>()
        for binding in bindings {
            if let session = sessions.first(where: { binding.matchesExactly($0) && !used.contains($0.id) }) {
                result[binding.id] = session.id
                used.insert(session.id)
            }
        }
        let byAge = sessions.sorted { $0.startTime < $1.startTime }
        for index in bindings.indices where result[bindings[index].id] == nil {
            let binding = bindings[index]
            guard let session = byAge.first(where: { candidate in
                !used.contains(candidate.id) && candidate.provider == binding.provider && candidate.cwd == binding.cwd
            }) else { continue }
            bindings[index].pid = session.pid
            bindings[index].pidStart = session.startTime
            result[binding.id] = session.id
            used.insert(session.id)
        }
        return result
    }
}
