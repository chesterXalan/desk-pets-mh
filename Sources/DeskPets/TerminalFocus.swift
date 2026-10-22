import AppKit
import DeskPetsCore

/// 喚起 session 所在的終端，並定位 tmux pane 或 cmux 分頁。
@MainActor
enum TerminalFocus {
    static func focus(_ session: AgentSession, completion: (@Sendable (Bool) -> Void)? = nil) {
        if let location = session.tmux {
            focusTmux(location, completion: completion)
            return
        }
        guard let app = hostApp(of: session.pid) else {
            NSSound.beep()
            completion?(false)
            return
        }
        if app.bundleIdentifier == GhosttyControl.bundleIdentifier {
            do {
                try GhosttyAutomation.focus(directory: session.cwd)
                bringToFront(app)
                completion?(true)
            } catch {
                if completion == nil {
                    let alert = NSAlert()
                    alert.messageText = L.t("error.terminalFocus")
                    alert.informativeText = L.error(error)
                    NSApplication.shared.activate()
                    alert.runModal()
                }
                completion?(false)
            }
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

    private static func focusTmux(_ location: TmuxLocation, completion: (@Sendable (Bool) -> Void)?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let clients = TmuxControl.clients(for: location)
            DispatchQueue.main.async {
                guard let (client, app) = clients.lazy.compactMap({ client in
                    hostApp(of: client.pid).map { (client, $0) }
                }).first else {
                    NSSound.beep()
                    completion?(false)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let switched = TmuxControl.focus(location, client: client)
                    DispatchQueue.main.async {
                        if switched { bringToFront(app) } else { NSSound.beep() }
                        completion?(switched)
                    }
                }
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
