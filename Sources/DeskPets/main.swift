import AppKit
import DeskPetsCore

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
