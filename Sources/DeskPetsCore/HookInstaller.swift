import Foundation

public enum HookInstallerError: LocalizedError {
    case notAnObject(String)
    case malformedHooks(String)

    public var errorDescription: String? {
        switch self {
        case .notAnObject(let path): return "\(path) is not a JSON object; nothing was changed."
        case .malformedHooks(let path): return "\(path) has an unexpected \"hooks\" layout; nothing was changed."
        }
    }
}

/// Merges DeskPets hook entries into ~/.claude/settings.json and ~/.codex/hooks.json,
/// leaving every other hook untouched and backing the file up before each write.
public struct HookInstaller {
    public static let marker = "deskpets-hook-v1"
    public static let claudeEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest",
                                      "Notification", "PreCompact", "Stop", "SessionEnd"]
    public static let codexEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest",
                                     "Stop", "SessionEnd", "PreCompact", "PostCompact"]

    public struct Change: Equatable {
        public var file: URL
        public var backup: URL?
    }

    public var paths: AppPaths
    public var hookExecutable: String
    public var now: () -> Date

    public init(paths: AppPaths, hookExecutable: String, now: @escaping () -> Date = Date.init) {
        self.paths = paths
        self.hookExecutable = hookExecutable
        self.now = now
    }

    public func file(for provider: Provider) -> URL {
        provider == .claude ? paths.claudeSettings : paths.codexHooks
    }

    public func command(for provider: Provider) -> String {
        "\(Self.shellQuote(hookExecutable)) record --provider \(provider.rawValue) --marker \(Self.marker)"
    }

    public func isInstalled(_ provider: Provider) -> Bool {
        guard let data = try? Data(contentsOf: file(for: provider)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = object["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { entries in
            (entries as? [[String: Any]])?.contains { entry in
                (entry["hooks"] as? [Any])?.contains(where: Self.isOurs) ?? false
            } ?? false
        }
    }

    @discardableResult
    public func install(_ providers: [Provider] = Provider.allCases) throws -> [Change] {
        try providers.compactMap { try update($0, install: true) }
    }

    @discardableResult
    public func uninstall(_ providers: [Provider] = Provider.allCases) throws -> [Change] {
        try providers.compactMap { try update($0, install: false) }
    }

    private func update(_ provider: Provider, install: Bool) throws -> Change? {
        let target = file(for: provider).resolvingSymlinksInPath()
        let manager = FileManager.default
        let original = manager.fileExists(atPath: target.path) ? try Data(contentsOf: target) : nil
        if original == nil && !install { return nil }
        var config: [String: Any] = [:]
        if let original, !original.allSatisfy({ $0 == 0x20 || $0 == 0x0a || $0 == 0x0d || $0 == 0x09 }) {
            guard let object = try JSONSerialization.jsonObject(with: original) as? [String: Any] else {
                throw HookInstallerError.notAnObject(target.path)
            }
            config = object
        }
        let before = try Self.canonical(config)
        try Self.strip(&config, path: target.path)
        if install {
            var hooks = config["hooks"] as? [String: Any] ?? [:]
            let entry: [String: Any] = ["hooks": [["type": "command", "command": command(for: provider), "timeout": 5]]]
            for event in provider == .claude ? Self.claudeEvents : Self.codexEvents {
                hooks[event] = (hooks[event] as? [Any] ?? []) + [entry]
            }
            config["hooks"] = hooks
        }
        guard try Self.canonical(config) != before else { return nil }

        var backup: URL?
        if let original {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            var candidate = target.deletingLastPathComponent()
                .appendingPathComponent("\(target.lastPathComponent).deskpets-\(formatter.string(from: now())).bak")
            var counter = 1
            while manager.fileExists(atPath: candidate.path) {
                counter += 1
                candidate = target.deletingLastPathComponent()
                    .appendingPathComponent("\(target.lastPathComponent).deskpets-\(formatter.string(from: now()))-\(counter).bak")
            }
            try original.write(to: candidate)
            try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: candidate.path)
            backup = candidate
        }
        try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        var output = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        output.append(0x0a)
        try output.write(to: target, options: .atomic)
        return Change(file: target, backup: backup)
    }

    /// Removes only our entries; other hooks and their grouping stay as they were.
    static func strip(_ config: inout [String: Any], path: String) throws {
        guard let raw = config["hooks"] else { return }
        guard var hooks = raw as? [String: Any] else { throw HookInstallerError.malformedHooks(path) }
        for (event, value) in hooks {
            guard let entries = value as? [Any] else { throw HookInstallerError.malformedHooks(path) }
            var kept: [Any] = []
            for entry in entries {
                guard var group = entry as? [String: Any], let list = group["hooks"] as? [Any] else {
                    kept.append(entry)
                    continue
                }
                let remaining = list.filter { !isOurs($0) }
                if remaining.count == list.count {
                    kept.append(entry)
                } else if !remaining.isEmpty {
                    group["hooks"] = remaining
                    kept.append(group)
                }
            }
            hooks[event] = kept.isEmpty ? nil : kept
        }
        config["hooks"] = hooks.isEmpty ? nil : hooks
    }

    static func isOurs(_ hook: Any) -> Bool {
        guard let hook = hook as? [String: Any], let command = hook["command"] as? String else { return false }
        return command.contains("--marker \(marker)")
    }

    static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func canonical(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
