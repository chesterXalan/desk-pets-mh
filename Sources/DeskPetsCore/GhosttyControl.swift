import Foundation

public struct GhosttyTerminal: Equatable, Sendable {
    public var id: UUID
    public var directory: String

    public init(id: UUID, directory: String) {
        self.id = id
        self.directory = directory
    }
}

public enum GhosttyFocusError: Error, Equatable {
    case automationDenied
    case unavailable
    case notFound
    case ambiguous
}

public enum GhosttyControl {
    public static let bundleIdentifier = "com.mitchellh.ghostty"

    // Ghostty 1.3 exposes a surface's directory, but not its PID or TTY.
    public static func target(directory: String, terminals: [GhosttyTerminal]) throws -> GhosttyTerminal {
        guard let directory = canonicalDirectory(directory) else { throw GhosttyFocusError.notFound }
        let matches = terminals.filter { canonicalDirectory($0.directory) == directory }
        guard let target = matches.first else { throw GhosttyFocusError.notFound }
        guard matches.count == 1 else { throw GhosttyFocusError.ambiguous }
        return target
    }

    private static func canonicalDirectory(_ path: String) -> String? {
        guard path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
