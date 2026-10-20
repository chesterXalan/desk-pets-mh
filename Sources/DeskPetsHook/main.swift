import DeskPetsCore
import Foundation

// deskpets-hook: a tiny recorder that Claude Code / Codex run on every hook event.
//   deskpets-hook record --provider claude|codex   (reads the hook payload on stdin)
//   deskpets-hook install|uninstall [--provider claude|codex] [--home DIR]
//   deskpets-hook pets show|hide                    (same as the menu's "Show Pets")
//   deskpets-hook list                              (detected sessions and their hook state)
// It must never block or fail the agent, so `record` always exits 0.

let arguments = Array(CommandLine.arguments.dropFirst())

func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func logError(_ paths: AppPaths, _ error: Error) {
    // Only the error type is logged; payloads may contain user prompts.
    let line = "\(Int(Date().timeIntervalSince1970)) \(type(of: error))\n"
    try? FileManager.default.createDirectory(at: paths.support, withIntermediateDirectories: true)
    if let handle = try? FileHandle(forWritingTo: paths.hookErrors) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    } else {
        try? Data(line.utf8).write(to: paths.hookErrors)
    }
}

struct HookInputError: Error {}

func record(provider: Provider) {
    let paths = AppPaths.current()
    do {
        let input = FileHandle.standardInput.readData(ofLength: 1024 * 1024 + 1)
        guard input.count <= 1024 * 1024,
              let payload = try JSONSerialization.jsonObject(with: input) as? [String: Any] else { throw HookInputError() }
        let agent = SessionScanner.agentAncestor().map { (pid: $0.pid, start: $0.start) }
        if let record = HookEvents.record(provider: provider, payload: payload, agent: agent) {
            _ = try HookEvents.write(record, to: paths.sessions)
        }
    } catch {
        logError(paths, error)
    }
    // Codex expects a JSON reply; an empty object never blocks it.
    if provider == .codex { print("{}") }
}

let command = arguments.first ?? ""
let provider = option("--provider").flatMap(Provider.init(rawValue:))

switch command {
case "record":
    record(provider: provider ?? .claude)
case "install", "uninstall":
    let home = option("--home").map { URL(fileURLWithPath: $0, isDirectory: true) }
    let paths = home.map(AppPaths.init(home:)) ?? AppPaths.current()
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.resolvingSymlinksInPath().path
    let installer = HookInstaller(paths: paths, hookExecutable: executable)
    let providers = provider.map { [$0] } ?? Provider.allCases
    do {
        let changes = command == "install" ? try installer.install(providers) : try installer.uninstall(providers)
        for change in changes {
            print("updated \(change.file.path)" + (change.backup.map { " (backup: \($0.path))" } ?? ""))
        }
        if changes.isEmpty { print("nothing to change") }
    } catch {
        FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
case "pets":
    guard arguments.count > 1, [PetsSwitch.show, PetsSwitch.hide].contains(arguments[1]) else {
        FileHandle.standardError.write(Data("usage: deskpets-hook pets show|hide\n".utf8))
        exit(2)
    }
    DistributedNotificationCenter.default().postNotificationName(PetsSwitch.name, object: arguments[1], userInfo: nil,
                                                                 deliverImmediately: true)
case "list":
    let sessions = SessionMerger.merge(SessionScanner.scan(), records: HookEvents.readAll(from: AppPaths.current().sessions))
    for session in sessions {
        print("\(session.provider.rawValue)\t\(session.pid)\t\(Int(session.startTime))\t\(session.state.rawValue)\t\(session.cwd)")
    }
default:
    FileHandle.standardError.write(Data("usage: deskpets-hook record|install|uninstall|list|pets [--provider claude|codex] [--home DIR]\n".utf8))
    exit(2)
}
