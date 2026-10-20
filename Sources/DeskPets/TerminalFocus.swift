import AppKit
import DeskPetsCore

/// Brings the terminal that hosts a session to the front. For cmux it also selects the
/// session's workspace and tab; other terminals only get their app activated.
enum TerminalFocus {
    static func focus(_ session: AgentSession, completion: (@Sendable (Bool) -> Void)? = nil) {
        guard let app = hostApp(of: session.pid) else {
            NSSound.beep()
            completion?(false)
            return
        }
        guard let location = session.cmux, app.bundleIdentifier == CmuxControl.bundleIdentifier else {
            bringToFront(app)
            completion?(true)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let switched = CmuxControl.focus(location)
            DispatchQueue.main.async {
                bringToFront(app)
                completion?(switched)
            }
        }
    }

    /// The nearest ancestor that is a regular (Dock) app, e.g. cmux for claude → zsh → login → cmux.
    static func hostApp(of pid: Int32) -> NSRunningApplication? {
        for process in ProcessTable.ancestors(of: pid) {
            if let app = NSRunningApplication(processIdentifier: process.pid), app.activationPolicy == .regular {
                return app
            }
        }
        return nil
    }

    private static func bringToFront(_ app: NSRunningApplication) {
        app.activate()
        // activate() can be ignored when Desk Pets itself is not active; Launch Services is not.
        if let url = app.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }
}
