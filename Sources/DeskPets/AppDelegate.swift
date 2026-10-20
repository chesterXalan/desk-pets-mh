import AppKit
import DeskPetsCore
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = AppController()
    private var statusItem: NSStatusItem!
    private var showItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var manageWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            Log.write("another instance is running; quitting")
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Desk Pets")
        image?.isTemplate = true
        statusItem.button?.image = image

        let menu = NSMenu()
        menu.delegate = self
        showItem = menu.addItem(withTitle: L.t("Show Pets", "顯示寵物"), action: #selector(toggleShow), keyEquivalent: "")
        menu.addItem(withTitle: L.t("Manage…", "管理…"), action: #selector(openManager), keyEquivalent: ",")
        loginItem = menu.addItem(withTitle: L.t("Launch at Login", "開機時啟動"), action: #selector(toggleLogin), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("Quit Desk Pets", "結束"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu
        let launched = ProcessTable.info(getpid())?.startTime ?? Date().timeIntervalSince1970
        Log.write(String(format: "menu bar item ready, %.0f ms after process start", (Date().timeIntervalSince1970 - launched) * 1000))
        controller.start()
        // `deskpets-hook pets show|hide` flips the same switch as the menu item, for scripts.
        DistributedNotificationCenter.default().addObserver(forName: PetsSwitch.name, object: nil, queue: .main) { [weak self] note in
            let show = note.object as? String != PetsSwitch.hide
            MainActor.assumeIsolated { self?.controller.setShowPets(show) }
        }
    }

    /// Opening the app again (Finder, Spotlight, `open`) while it runs shows the manager.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openManager()
        return false
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        showItem.state = controller.config.showPets ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleShow() {
        controller.setShowPets(!controller.config.showPets)
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc func openManager() {
        if manageWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: ManageView().environmentObject(controller)))
            window.title = L.t("Desk Pets", "Desk Pets 管理")
            window.setContentSize(NSSize(width: 720, height: 460))
            window.isReleasedWhenClosed = false
            window.center()
            manageWindow = window
        }
        NSApp.activate()
        manageWindow?.makeKeyAndOrderFront(nil)
    }
}

enum L {
    static let chinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false

    static func t(_ english: String, _ zh: String) -> String {
        chinese ? zh : english
    }
}

enum Log {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func write(_ message: String) {
        FileHandle.standardError.write(Data("[\(formatter.string(from: Date()))] \(message)\n".utf8))
    }
}
