import AppKit
import DeskPetsCore

// `DeskPets focus-session <pid>` runs the same code as double-clicking that session's pet.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "focus-session", let pid = Int32(CommandLine.arguments[2]) {
    guard var session = SessionScanner.scan().first(where: { $0.pid == pid }) else {
        FileHandle.standardError.write(Data("error: no claude/codex session with pid \(pid)\n".utf8))
        exit(1)
    }
    let paths = AppPaths.current()
    session.title = SessionNamer(home: paths.home).names(
        for: [session], records: HookEvents.readAll(from: paths.sessions))[session.id]
    MainActor.assumeIsolated {
        TerminalFocus.focus(session) { [session] switched in
            if session.tmux != nil {
                print(switched ? "switched tmux pane and activated host app" : "could not focus tmux pane")
            } else {
                print(switched ? "focused terminal" : "could not focus terminal")
            }
            exit(switched ? 0 : 1)
        }
    }
    RunLoop.main.run()
}

// `DeskPets import-character <name> <idle.gif> [working.gif] [waiting.gif]` imports without the UI.
let arguments = CommandLine.arguments
if arguments.count >= 4, arguments[1] == "import-character" {
    let paths = AppPaths.current()
    let library = CharacterLibrary(builtInRoot: AppController.builtInCharacters, customRoot: paths.characters)
    let files = arguments.dropFirst(3).map { URL(fileURLWithPath: $0) }
    do {
        let character = try library.importCharacter(name: arguments[2], idle: files[0],
                                                    working: files.count > 1 ? files[1] : nil,
                                                    waiting: files.count > 2 ? files[2] : nil)
        print("imported \(character.name) → \(character.directory.path)")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
