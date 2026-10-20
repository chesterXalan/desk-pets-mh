import Foundation

/// A character is a folder of GIFs: idle.gif is required, working.gif and waiting.gif are optional.
public struct CharacterInfo: Identifiable, Hashable, Sendable {
    public var name: String
    public var directory: URL
    public var builtIn: Bool

    public var id: String { name }

    public func gif(for state: PetState) -> URL {
        let idle = directory.appendingPathComponent("idle.gif")
        let wanted = directory.appendingPathComponent("\(state.animation).gif")
        return FileManager.default.fileExists(atPath: wanted.path) ? wanted : idle
    }
}

public enum CharacterError: LocalizedError, Equatable {
    case invalidName
    case alreadyExists(String)
    case notAGIF(String)
    case builtIn

    public var errorDescription: String? {
        switch self {
        case .invalidName: return "Character names cannot be empty, start with a dot, or contain “/” or “:”."
        case .alreadyExists(let name): return "A character named “\(name)” already exists."
        case .notAGIF(let file): return "“\(file)” is not a GIF file."
        case .builtIn: return "Built-in characters cannot be deleted."
        }
    }
}

public struct CharacterLibrary: Sendable {
    public var builtInRoot: URL?
    public var customRoot: URL

    public init(builtInRoot: URL?, customRoot: URL) {
        self.builtInRoot = builtInRoot
        self.customRoot = customRoot
    }

    public func list() -> [CharacterInfo] {
        let builtIn = Self.scan(builtInRoot, builtIn: true)
        let names = Set(builtIn.map(\.name))
        return builtIn + Self.scan(customRoot, builtIn: false).filter { !names.contains($0.name) }
    }

    public func character(named name: String) -> CharacterInfo? {
        list().first { $0.name == name }
    }

    @discardableResult
    public func importCharacter(name rawName: String, idle: URL, working: URL? = nil, waiting: URL? = nil) throws -> CharacterInfo {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"), !name.contains(":"), name.count <= 64 else {
            throw CharacterError.invalidName
        }
        guard character(named: name) == nil else { throw CharacterError.alreadyExists(name) }
        let sources = [("idle", idle), ("working", working), ("waiting", waiting)].compactMap { key, url in url.map { (key, $0) } }
        for (_, url) in sources where !Self.isGIF(url) {
            throw CharacterError.notAGIF(url.lastPathComponent)
        }
        let directory = customRoot.appendingPathComponent(name, isDirectory: true)
        let staging = customRoot.appendingPathComponent(".import-\(UUID().uuidString)", isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            for (key, url) in sources {
                try manager.copyItem(at: url, to: staging.appendingPathComponent("\(key).gif"))
            }
            try manager.moveItem(at: staging, to: directory)
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
        return CharacterInfo(name: name, directory: directory, builtIn: false)
    }

    public func delete(_ character: CharacterInfo) throws {
        guard !character.builtIn, character.directory.deletingLastPathComponent().standardizedFileURL == customRoot.standardizedFileURL else {
            throw CharacterError.builtIn
        }
        try FileManager.default.removeItem(at: character.directory)
    }

    public static func isGIF(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 6)) ?? Data()
        return header == Data("GIF89a".utf8) || header == Data("GIF87a".utf8)
    }

    private static func scan(_ root: URL?, builtIn: Bool) -> [CharacterInfo] {
        guard let root, let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        return entries
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("idle.gif").path) }
            .map { CharacterInfo(name: $0.lastPathComponent, directory: $0, builtIn: builtIn) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
