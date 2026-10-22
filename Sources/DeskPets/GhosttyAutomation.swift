import DeskPetsCore
import Foundation

@MainActor
enum GhosttyAutomation {
    static func focus(directory: String) throws {
        let result = try execute("""
            tell application id "com.mitchellh.ghostty"
                set surfaces to {}
                repeat with surface in terminals
                    set end of surfaces to {id of surface, working directory of surface}
                end repeat
                return surfaces
            end tell
            """)
        var terminals: [GhosttyTerminal] = []
        for index in 0..<result.numberOfItems {
            guard let row = result.atIndex(index + 1),
                  let idString = row.atIndex(1)?.stringValue, let id = UUID(uuidString: idString),
                  let directory = row.atIndex(2)?.stringValue else { throw GhosttyFocusError.unavailable }
            terminals.append(GhosttyTerminal(id: id, directory: directory))
        }
        let target = try GhosttyControl.target(directory: directory, terminals: terminals)
        // Only a validated UUID enters the script; paths and terminal titles never become code.
        _ = try execute("""
            tell application id "com.mitchellh.ghostty"
                focus (first terminal whose id is "\(target.id.uuidString)")
            end tell
            """)
    }

    private static func execute(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: "with timeout of 5 seconds\n\(source)\nend timeout") else {
            throw GhosttyFocusError.unavailable
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue == -1743 {
                throw GhosttyFocusError.automationDenied
            }
            throw GhosttyFocusError.unavailable
        }
        return result
    }
}
