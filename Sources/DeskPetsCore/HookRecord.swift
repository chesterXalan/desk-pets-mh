import Foundation

/// What a hook writes to `sessions/<session_id>.json`. Only metadata, never prompts or tool input.
public struct HookRecord: Codable, Equatable, Sendable {
    public var provider: Provider
    public var sessionId: String
    public var state: PetState
    public var event: String
    public var cwd: String
    public var pid: Int32
    public var pidStart: Double
    public var title: String?
    public var updatedAt: Double

    public init(provider: Provider, sessionId: String, state: PetState, event: String, cwd: String,
                pid: Int32, pidStart: Double, title: String? = nil, updatedAt: Double) {
        self.provider = provider
        self.sessionId = sessionId
        self.state = state
        self.event = event
        self.cwd = cwd
        self.pid = pid
        self.pidStart = pidStart
        self.title = title
        self.updatedAt = updatedAt
    }
}

public enum HookEvents {
    /// Maps a hook payload to the pet state it implies, or nil when the event says nothing about it.
    public static func state(for payload: [String: Any]) -> PetState? {
        guard let event = payload["hook_event_name"] as? String else { return nil }
        switch event {
        case "SessionStart":
            return (payload["source"] as? String) == "compact" ? .working : .idle
        case "UserPromptSubmit", "PreToolUse", "PostToolUse", "PreCompact", "PostCompact", "ElicitationResult":
            return .working
        case "PermissionRequest", "Elicitation":
            return .waiting
        case "Notification":
            // permission_prompt and idle_prompt both mean the agent waits on the user.
            return (payload["notification_type"] as? String) == "auth_success" ? nil : .waiting
        case "Stop", "Interrupt":
            return .idle
        case "SessionEnd":
            return .exited
        default:
            return nil
        }
    }

    /// Builds a record from a raw payload. Returns nil for events to ignore (subagents, unknown events).
    public static func record(provider: Provider, payload: [String: Any], agent: (pid: Int32, start: Double)?,
                              now: Date = Date()) -> HookRecord? {
        if payload["agent_id"] != nil { return nil }
        let event = clean(payload["hook_event_name"], limit: 64)
        if event.hasPrefix("Subagent") { return nil }
        guard let state = state(for: payload) else { return nil }
        let sessionId = clean(payload["session_id"], limit: 128)
        guard !sessionId.isEmpty || agent != nil else { return nil }
        let title = clean(payload["session_title"] ?? payload["title"], limit: 120)
        return HookRecord(provider: provider,
                          sessionId: sessionId,
                          state: state,
                          event: event,
                          cwd: clean(payload["cwd"], limit: 4096),
                          pid: agent?.pid ?? 0,
                          pidStart: agent?.start ?? 0,
                          title: title.isEmpty ? nil : title,
                          updatedAt: now.timeIntervalSince1970)
    }

    /// File name for a record: the session id when it is filename-safe, otherwise a pid-based name.
    public static func fileName(for record: HookRecord) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let id = record.sessionId
        if !id.isEmpty, id.unicodeScalars.allSatisfy(allowed.contains) {
            return "\(id).json"
        }
        return "\(record.provider.rawValue)-pid-\(record.pid).json"
    }

    public static func write(_ record: HookRecord, to directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent(fileName(for: record))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: url, options: .atomic)
        return url
    }

    public static func readAll(from directory: URL) -> [HookRecord] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        return files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url), data.count < 64 * 1024 else { return nil }
            return try? decoder.decode(HookRecord.self, from: data)
        }
    }

    private static func clean(_ value: Any?, limit: Int) -> String {
        guard let text = value as? String else { return "" }
        return String(text.prefix(limit).unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7f }.map(Character.init))
    }
}

public enum SessionMerger {
    /// Attaches the newest matching hook record (same pid and start time) to each detected process.
    public static func merge(_ sessions: [AgentSession], records: [HookRecord]) -> [AgentSession] {
        sessions.map { session in
            var session = session
            let match = records
                .filter { $0.provider == session.provider && $0.pid == session.pid && abs($0.pidStart - session.startTime) < 2 }
                .max { $0.updatedAt < $1.updatedAt }
            if let match {
                session.state = match.state == .exited ? .unknown : match.state
                session.sessionId = match.sessionId.isEmpty ? nil : match.sessionId
                session.title = match.title
            }
            return session
        }
    }
}
