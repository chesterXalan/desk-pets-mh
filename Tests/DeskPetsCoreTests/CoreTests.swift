import Foundation
import Testing
@testable import DeskPetsCore

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("deskpets-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite struct HookEventTests {
    @Test func mapsEventsToStates() {
        #expect(HookEvents.state(for: ["hook_event_name": "UserPromptSubmit"]) == .working)
        #expect(HookEvents.state(for: ["hook_event_name": "PreToolUse"]) == .working)
        #expect(HookEvents.state(for: ["hook_event_name": "Notification", "notification_type": "permission_prompt"]) == .waiting)
        #expect(HookEvents.state(for: ["hook_event_name": "Notification", "notification_type": "idle_prompt"]) == .waiting)
        #expect(HookEvents.state(for: ["hook_event_name": "PermissionRequest"]) == .waiting)
        #expect(HookEvents.state(for: ["hook_event_name": "Stop"]) == .idle)
        #expect(HookEvents.state(for: ["hook_event_name": "SessionStart", "source": "startup"]) == .idle)
        #expect(HookEvents.state(for: ["hook_event_name": "SessionEnd"]) == .exited)
        #expect(HookEvents.state(for: ["hook_event_name": "SomethingNew"]) == nil)
        #expect(HookEvents.state(for: [:]) == nil)
    }

    @Test func buildsRecordWithoutConversationContent() throws {
        let payload: [String: Any] = ["hook_event_name": "UserPromptSubmit", "session_id": "abc-123", "cwd": "/tmp/project",
                                      "prompt": "secret prompt text"]
        let record = try #require(HookEvents.record(provider: .claude, payload: payload, agent: (pid: 42, start: 1000),
                                                    now: Date(timeIntervalSince1970: 5)))
        #expect(record.state == .working)
        #expect(record.pid == 42)
        #expect(record.cwd == "/tmp/project")
        let encoded = String(decoding: try JSONEncoder().encode(record), as: UTF8.self)
        #expect(!encoded.contains("secret"))
    }

    @Test func ignoresSubagentsAndUnknownEvents() {
        #expect(HookEvents.record(provider: .claude, payload: ["hook_event_name": "Stop", "session_id": "a", "agent_id": "x"], agent: nil) == nil)
        #expect(HookEvents.record(provider: .claude, payload: ["hook_event_name": "SubagentStop", "session_id": "a"], agent: nil) == nil)
        #expect(HookEvents.record(provider: .claude, payload: ["hook_event_name": "Mystery", "session_id": "a"], agent: nil) == nil)
        #expect(HookEvents.record(provider: .claude, payload: ["hook_event_name": "Stop"], agent: nil) == nil)
    }

    @Test func writesAndReadsRecordsBySessionId() throws {
        let directory = try temporaryDirectory()
        let record = HookRecord(provider: .codex, sessionId: "s-1", state: .waiting, event: "PermissionRequest",
                                cwd: "/x", pid: 7, pidStart: 1, updatedAt: 2)
        let url = try HookEvents.write(record, to: directory)
        #expect(url.lastPathComponent == "s-1.json")
        #expect(HookEvents.readAll(from: directory) == [record])
        let unsafe = HookRecord(provider: .claude, sessionId: "../evil", state: .idle, event: "Stop", cwd: "", pid: 9, pidStart: 0, updatedAt: 0)
        #expect(HookEvents.fileName(for: unsafe) == "claude-pid-9.json")
    }
}

@Suite struct StateMergeTests {
    @Test func latestMatchingRecordWins() {
        let session = AgentSession(provider: .claude, pid: 10, startTime: 100, cwd: "/a")
        let records = [
            HookRecord(provider: .claude, sessionId: "s", state: .working, event: "PreToolUse", cwd: "/a", pid: 10, pidStart: 100.4, updatedAt: 1),
            HookRecord(provider: .claude, sessionId: "s", state: .waiting, event: "Notification", cwd: "/a", pid: 10, pidStart: 100.4, updatedAt: 2),
            HookRecord(provider: .claude, sessionId: "old", state: .idle, event: "Stop", cwd: "/a", pid: 10, pidStart: 50, updatedAt: 3),
        ]
        #expect(SessionMerger.merge([session], records: records).first?.state == .waiting)
        #expect(SessionMerger.merge([session], records: []).first?.state == .unknown)
    }

    @Test func transitionsFollowEventOrder() {
        let session = AgentSession(provider: .claude, pid: 10, startTime: 100, cwd: "/a")
        var records: [HookRecord] = []
        var seen: [PetState] = []
        for (index, event) in ["SessionStart", "UserPromptSubmit", "Notification", "PreToolUse", "Stop"].enumerated() {
            let record = HookEvents.record(provider: .claude, payload: ["hook_event_name": event, "session_id": "s"],
                                           agent: (pid: 10, start: 100), now: Date(timeIntervalSince1970: Double(index)))!
            records.append(record)
            seen.append(SessionMerger.merge([session], records: records)[0].state)
        }
        #expect(seen == [.idle, .working, .waiting, .working, .idle])
    }

    @Test func classifiesAgentProcesses() {
        #expect(AgentClassifier.provider(comm: "claude", path: "/Users/u/.local/bin/claude", arguments: ["claude"]) == .claude)
        #expect(AgentClassifier.provider(comm: "2.1.302", path: "/Users/u/.local/share/claude/versions/2.1.302", arguments: []) == .claude)
        #expect(AgentClassifier.provider(comm: "node", path: "/opt/node", arguments: ["node", "/usr/local/bin/codex"]) == .codex)
        #expect(AgentClassifier.provider(comm: "node", path: "/opt/node", arguments: ["node", "server.js"]) == nil)
        #expect(AgentClassifier.isInteractive(arguments: ["claude", "--settings", "x.json"]))
        #expect(!AgentClassifier.isInteractive(arguments: ["claude", "daemon", "run"]))
        #expect(!AgentClassifier.isInteractive(arguments: ["claude", "attach", "abc"]))
        #expect(!AgentClassifier.isInteractive(arguments: ["claude", "-p", "hi"]))
    }

    @Test func scannerFindsNoSessionsForBogusPid() {
        #expect(ProcessTable.info(-5) == nil)
        #expect(!ProcessTable.all().isEmpty)
        #expect(ProcessTable.info(getpid())?.pid == getpid())
    }
}

@Suite struct ConfigTests {
    @Test func roundTripsAndToleratesMissingFields() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("nested/config.json")
        var config = AppConfig(showPets: false, petSize: 128)
        config.bindings = [PetBinding(provider: .codex, cwd: "/p", character: "ghost", pid: 3, pidStart: 4, x: 10, y: 20)]
        try config.save(to: url)
        #expect(AppConfig.load(from: url) == config)

        try Data(#"{"petSize": 64}"#.utf8).write(to: url)
        let partial = AppConfig.load(from: url)
        #expect(partial.petSize == 64 && partial.showPets && partial.bindings.isEmpty)

        try Data("not json".utf8).write(to: url)
        #expect(AppConfig.load(from: url) == AppConfig())
    }

    @Test func reattachesBindingAfterRestart() {
        var bindings = [PetBinding(provider: .claude, cwd: "/work/app", character: "cat", pid: 100, pidStart: 1000)]
        let restarted = [
            AgentSession(provider: .codex, pid: 300, startTime: 3000, cwd: "/work/app"),
            AgentSession(provider: .claude, pid: 200, startTime: 2000, cwd: "/work/app"),
            AgentSession(provider: .claude, pid: 250, startTime: 2500, cwd: "/work/app"),
        ]
        let resolved = BindingResolver.resolve(&bindings, sessions: restarted)
        #expect(resolved[bindings[0].id] == restarted[1].id)
        #expect(bindings[0].pid == 200 && bindings[0].pidStart == 2000)
    }

    @Test func exactMatchesAreNotStolen() {
        let a = PetBinding(provider: .claude, cwd: "/w", character: "cat", pid: 2, pidStart: 20)
        let b = PetBinding(provider: .claude, cwd: "/w", character: "ghost", pid: 99, pidStart: 1)
        var bindings = [b, a]
        let sessions = [AgentSession(provider: .claude, pid: 1, startTime: 10, cwd: "/w"),
                        AgentSession(provider: .claude, pid: 2, startTime: 20, cwd: "/w")]
        let resolved = BindingResolver.resolve(&bindings, sessions: sessions)
        #expect(resolved[a.id] == sessions[1].id)
        #expect(resolved[b.id] == sessions[0].id)
        #expect(bindings[0].pid == 1)
    }

    @Test func unmatchedBindingStaysOffline() {
        var bindings = [PetBinding(provider: .claude, cwd: "/gone", character: "cat", pid: 5, pidStart: 5)]
        let resolved = BindingResolver.resolve(&bindings, sessions: [AgentSession(provider: .claude, pid: 6, startTime: 6, cwd: "/other")])
        #expect(resolved.isEmpty)
        #expect(bindings[0].pid == 5)
    }
}

@Suite struct HookInstallerTests {
    private func installer(_ home: URL) -> HookInstaller {
        HookInstaller(paths: AppPaths(home: home), hookExecutable: "/Applications/Desk Pets.app/Contents/MacOS/deskpets-hook",
                      now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func json(_ url: URL) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    @Test func installKeepsUserHooksAndBacksUp() throws {
        let home = try temporaryDirectory()
        let settings = home.appendingPathComponent(".claude/settings.json")
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = #"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#
        try Data(original.utf8).write(to: settings)

        let changes = try installer(home).install([.claude])
        #expect(changes.count == 1)
        let backup = try #require(changes[0].backup)
        #expect(backup.lastPathComponent.hasPrefix("settings.json.deskpets-"))
        #expect(String(decoding: try Data(contentsOf: backup), as: UTF8.self) == original)

        let config = try json(settings)
        #expect(config["model"] as? String == "opus")
        let hooks = try #require(config["hooks"] as? [String: Any])
        let stop = try #require(hooks["Stop"] as? [[String: Any]])
        #expect(stop.count == 2)
        #expect(String(describing: stop[0]).contains("say done"))
        #expect(Set(hooks.keys) == Set(HookInstaller.claudeEvents))
        #expect(installer(home).isInstalled(.claude))
        #expect(!installer(home).isInstalled(.codex))

        // Installing twice changes nothing.
        #expect(try installer(home).install([.claude]).isEmpty)
    }

    @Test func uninstallRestoresOnlyUserHooks() throws {
        let home = try temporaryDirectory()
        let settings = home.appendingPathComponent(".claude/settings.json")
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#.utf8).write(to: settings)
        try installer(home).install([.claude])
        try installer(home).uninstall([.claude])

        let hooks = try #require(try json(settings)["hooks"] as? [String: Any])
        #expect(Array(hooks.keys) == ["Stop"])
        #expect(!installer(home).isInstalled(.claude))
    }

    @Test func createsMissingFilesAndRefusesBrokenOnes() throws {
        let home = try temporaryDirectory()
        let changes = try installer(home).install([.codex])
        #expect(changes.first?.backup == nil)
        #expect(installer(home).isInstalled(.codex))
        let command = String(decoding: try Data(contentsOf: home.appendingPathComponent(".codex/hooks.json")), as: UTF8.self)
        #expect(command.contains("'/Applications/Desk Pets.app/Contents/MacOS/deskpets-hook' record --provider codex"))

        // Nothing to remove when the file never existed.
        #expect(try installer(home).uninstall([.claude]).isEmpty)

        let settings = home.appendingPathComponent(".claude/settings.json")
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ broken".utf8).write(to: settings)
        #expect(throws: (any Error).self) { try installer(home).install([.claude]) }
        #expect(String(decoding: try Data(contentsOf: settings), as: UTF8.self) == "{ broken")
    }
}

@Suite struct CharacterLibraryTests {
    private func gif(in directory: URL, name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("GIF89a-fake".utf8).write(to: url)
        return url
    }

    @Test func importsListsAndDeletes() throws {
        let root = try temporaryDirectory()
        let builtIn = root.appendingPathComponent("builtin/cat", isDirectory: true)
        try FileManager.default.createDirectory(at: builtIn, withIntermediateDirectories: true)
        _ = try gif(in: builtIn, name: "idle.gif")
        let library = CharacterLibrary(builtInRoot: root.appendingPathComponent("builtin"), customRoot: root.appendingPathComponent("custom"))

        let idle = try gif(in: root, name: "a.gif")
        let character = try library.importCharacter(name: "  Mochi ", idle: idle)
        #expect(character.name == "Mochi")
        #expect(library.list().map(\.name) == ["cat", "Mochi"])
        // Missing optional animations fall back to idle.
        #expect(character.gif(for: .working).lastPathComponent == "idle.gif")

        #expect(throws: CharacterError.alreadyExists("Mochi")) { try library.importCharacter(name: "Mochi", idle: idle) }
        #expect(throws: CharacterError.invalidName) { try library.importCharacter(name: "../x", idle: idle) }
        let text = root.appendingPathComponent("b.gif")
        try Data("hello".utf8).write(to: text)
        #expect(throws: CharacterError.notAGIF("b.gif")) { try library.importCharacter(name: "Bad", idle: text) }

        #expect(throws: CharacterError.builtIn) { try library.delete(library.character(named: "cat")!) }
        try library.delete(character)
        #expect(library.list().map(\.name) == ["cat"])
    }
}
