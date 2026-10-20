import AppKit
import DeskPetsCore
import SwiftUI
import UniformTypeIdentifiers

struct ManageView: View {
    var body: some View {
        TabView {
            SessionsTab().tabItem { Text(L.t("Sessions", "Sessions")) }
            CharactersTab().tabItem { Text(L.t("Characters", "角色")) }
            HooksTab().tabItem { Text("Hooks") }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 400)
    }
}

// MARK: - Sessions

private struct SessionsTab: View {
    @EnvironmentObject private var app: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Table(app.sessions) {
                TableColumn(L.t("Session", "Session")) { session in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: session.displayName)
                        if session.title != nil {
                            Text(verbatim: session.location).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .help(session.cwd)
                }
                TableColumn("CLI") { session in Text(session.provider.rawValue) }
                    .width(60)
                TableColumn(L.t("State", "狀態")) { session in StateLabel(state: session.state) }
                    .width(110)
                TableColumn(L.t("Pet", "寵物")) { session in
                    Picker("", selection: Binding(
                        get: { app.binding(for: session)?.character ?? "" },
                        set: { app.setPet($0.isEmpty ? nil : $0, for: session) })) {
                        Text(L.t("None", "不綁定")).tag("")
                        ForEach(app.characters) { Text($0.name).tag($0.name) }
                    }
                    .labelsHidden()
                }
                .width(150)
            }
            if !app.offlineBindings.isEmpty {
                Text(L.t("Waiting for their session to start again:", "等待 session 重新開啟的寵物："))
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(app.offlineBindings) { binding in
                    HStack {
                        Text(verbatim: "\(binding.character) · \(binding.provider.rawValue) · \(binding.cwd)")
                            .font(.caption).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(L.t("Remove", "移除")) { app.unbind(binding.id) }.controlSize(.small)
                    }
                }
            }
            HStack {
                Toggle(L.t("Show pets", "顯示寵物"), isOn: Binding(get: { app.config.showPets }, set: { app.setShowPets($0) }))
                Spacer()
                SizePicker()
            }
        }
    }
}

private struct StateLabel: View {
    let state: PetState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name)
        }
    }

    private var color: Color {
        switch state {
        case .working: return .green
        case .waiting: return .orange
        case .idle: return .gray
        case .unknown, .exited: return .gray.opacity(0.3)
        }
    }

    private var name: String {
        switch state {
        case .working: return L.t("Working", "工作中")
        case .waiting: return L.t("Waiting", "等你回覆")
        case .idle: return L.t("Idle", "閒置")
        case .unknown, .exited: return L.t("Unknown", "未知")
        }
    }
}

private struct SizePicker: View {
    @EnvironmentObject private var app: AppController

    var body: some View {
        Picker(L.t("Size", "大小"), selection: Binding(get: { app.config.petSize }, set: { app.setPetSize($0) })) {
            ForEach(AppConfig.sizes, id: \.self) { Text("\($0) px").tag($0) }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
}

// MARK: - Characters

private struct CharactersTab: View {
    @EnvironmentObject private var app: AppController
    @StateObject private var ui = CharactersUI()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            List(app.characters) { character in
                HStack(spacing: 12) {
                    GIFThumbnail(url: character.gif(for: .idle))
                    VStack(alignment: .leading) {
                        Text(character.name)
                        Text(character.builtIn ? L.t("Built-in", "內建") : character.directory.path)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    if !character.builtIn {
                        Button(L.t("Delete…", "刪除…")) { ui.pendingDelete = character }
                    }
                }
                .padding(.vertical, 2)
            }
            HStack {
                Button(L.t("Add Character…", "新增角色…")) { ui.adding = true }
                Text(L.t("A character is idle.gif, plus optional working.gif and waiting.gif.",
                         "一個角色＝idle.gif（必填）＋ working.gif、waiting.gif（選填）。"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                SizePicker()
            }
        }
        .sheet(isPresented: $ui.adding) { AddCharacterSheet() }
        .confirmationDialog(L.t("Delete this character?", "刪除這個角色？"), isPresented: Binding(
            get: { ui.pendingDelete != nil }, set: { if !$0 { ui.pendingDelete = nil } }), presenting: ui.pendingDelete) { character in
            Button(L.t("Delete “\(character.name)”", "刪除「\(character.name)」"), role: .destructive) {
                do { try app.deleteCharacter(character) } catch { ui.error = error.localizedDescription }
            }
        }
        .alert(ui.error ?? "", isPresented: Binding(get: { ui.error != nil }, set: { if !$0 { ui.error = nil } })) {}
    }
}

private struct GIFThumbnail: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.none).aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "questionmark.square.dashed")
            }
        }
        .frame(width: 40, height: 40)
    }
}

private struct AddCharacterSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var form = CharacterForm()

    private static let slots = [("idle", L.t("Idle (required)", "閒置（必填）")),
                                ("working", L.t("Working (optional)", "工作中（選填）")),
                                ("waiting", L.t("Waiting (optional)", "等你回覆（選填）"))]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("New Character", "新增角色")).font(.headline)
            TextField(L.t("Name", "名字"), text: $form.name)
            ForEach(Self.slots, id: \.0) { key, title in
                HStack {
                    Text(title).frame(width: 140, alignment: .leading)
                    Text(form.files[key]?.lastPathComponent ?? "—")
                        .foregroundStyle(form.files[key] == nil ? .secondary : .primary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if form.files[key] != nil {
                        Button(L.t("Clear", "清除")) { form.files[key] = nil }
                    }
                    Button(L.t("Choose…", "選擇…")) { choose(key) }
                }
            }
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.secondary)
                .frame(height: 60)
                .overlay(Text(L.t("Or drop 1–3 GIFs here (named idle / working / waiting)",
                                  "或把 1～3 張 GIF 拖進來（檔名 idle／working／waiting）"))
                    .font(.caption).foregroundStyle(.secondary))
                .dropDestination(for: URL.self) { urls, _ in
                    assign(urls)
                    return true
                }
            if let error = form.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(L.t("Cancel", "取消")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L.t("Add", "新增")) { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(form.name.trimmingCharacters(in: .whitespaces).isEmpty || form.files["idle"] == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func choose(_ key: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { form.files[key] = url }
    }

    private func assign(_ urls: [URL]) {
        let gifs = urls.filter { $0.pathExtension.lowercased() == "gif" }
        var unnamed: [URL] = []
        for url in gifs {
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()
            if ["idle", "working", "waiting"].contains(stem) { form.files[stem] = url } else { unnamed.append(url) }
        }
        for url in unnamed {
            if let free = ["idle", "working", "waiting"].first(where: { form.files[$0] == nil }) { form.files[free] = url }
        }
        if form.name.isEmpty, let first = gifs.first {
            form.name = first.deletingLastPathComponent().lastPathComponent
        }
    }

    private func add() {
        guard let idle = form.files["idle"] else { return }
        do {
            try app.importCharacter(name: form.name, idle: idle, working: form.files["working"], waiting: form.files["waiting"])
            dismiss()
        } catch {
            form.error = error.localizedDescription
        }
    }
}

// MARK: - Hooks

private struct HooksTab: View {
    @EnvironmentObject private var app: AppController
    @StateObject private var ui = MessageUI()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("Hooks tell Desk Pets whether a session is working, waiting for you, or idle. Without them every pet shows “unknown”.",
                     "Hooks 讓寵物知道 session 是工作中、等你回覆還是閒置；沒有 hooks 時狀態一律顯示「未知」。"))
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Claude Code").bold()
                    Text(app.paths.claudeSettings.path).font(.caption.monospaced())
                    Text(status(.claude))
                }
                GridRow {
                    Text("Codex").bold()
                    Text(app.paths.codexHooks.path).font(.caption.monospaced())
                    Text(status(.codex))
                }
            }
            Text(L.t("Your existing hooks are kept. The file is backed up as *.deskpets-<time>.bak before every change. Sessions pick up new hooks after a restart.",
                     "會保留你原有的 hooks；每次修改前會備份成 *.deskpets-<時間>.bak。已開著的 session 要重開才會載入新 hooks。"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L.t("Install Hooks", "安裝 hooks")) { run { try app.installHooks() } }
                Button(L.t("Remove Hooks", "移除 hooks")) { run { try app.uninstallHooks() } }
            }
            if !ui.message.isEmpty {
                Text(ui.message).font(.caption.monospaced()).textSelection(.enabled)
            }
            Spacer()
        }
        .onAppear { app.refreshHookStatus() }
    }

    private func status(_ provider: Provider) -> String {
        app.hooksInstalled[provider] == true ? L.t("Installed", "已安裝") : L.t("Not installed", "未安裝")
    }

    private func run(_ action: () throws -> [HookInstaller.Change]) {
        do {
            let changes = try action()
            ui.message = changes.isEmpty
                ? L.t("Nothing to change.", "沒有需要修改的地方。")
                : changes.map { "✓ \($0.file.path)" + ($0.backup.map { "\n   backup: \($0.lastPathComponent)" } ?? "") }.joined(separator: "\n")
        } catch {
            ui.message = error.localizedDescription
        }
    }
}

// SwiftUI's @State is a macro the Command Line Tools cannot expand, so view state lives in small objects.
private final class CharactersUI: ObservableObject {
    @Published var adding = false
    @Published var pendingDelete: CharacterInfo?
    @Published var error: String?
}

private final class CharacterForm: ObservableObject {
    @Published var name = ""
    @Published var files: [String: URL] = [:]
    @Published var error: String?
}

private final class MessageUI: ObservableObject {
    @Published var message = ""
}
