import Foundation

public struct GhosttyTerminal: Equatable, Sendable {
    public var id: UUID
    public var directory: String
    public var title: String

    public init(id: UUID, directory: String, title: String = "") {
        self.id = id
        self.directory = directory
        self.title = title
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
    public static func target(directory: String, title: String? = nil,
                              terminals: [GhosttyTerminal], allowTitleFallback: Bool = false) throws -> GhosttyTerminal {
        guard let directory = canonicalDirectory(directory) else { throw GhosttyFocusError.notFound }
        let matches = terminals.filter { canonicalDirectory($0.directory) == directory }
        guard let target = matches.first else {
            // 非 tmux 的 shell integration 目錄可能過期，只接受唯一的完整對話標題。
            let title = title.map(CmuxTree.cleanTitle) ?? ""
            guard allowTitleFallback, !title.isEmpty else { throw GhosttyFocusError.notFound }
            let titled = terminals.filter { CmuxTree.cleanTitle($0.title) == title }
            guard !titled.isEmpty else { throw GhosttyFocusError.notFound }
            guard titled.count == 1, let target = titled.first else { throw GhosttyFocusError.ambiguous }
            return target
        }
        if matches.count == 1 { return target }
        // CLI 標題會帶有狀態符號；只接受同目錄內唯一的完整標題配對。
        let title = title.map(CmuxTree.cleanTitle) ?? ""
        guard !title.isEmpty else { throw GhosttyFocusError.ambiguous }
        let titled = matches.filter { CmuxTree.cleanTitle($0.title) == title }
        guard titled.count == 1, let target = titled.first else { throw GhosttyFocusError.ambiguous }
        return target
    }

    private static func canonicalDirectory(_ path: String) -> String? {
        guard path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
