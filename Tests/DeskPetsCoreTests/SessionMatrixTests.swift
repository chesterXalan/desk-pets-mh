import Foundation
import Testing
@testable import DeskPetsCore

@Suite struct SessionMatrixTests {
    @Test(arguments: [false, true], [false, true])
    func independentStatesAcrossProvidersTerminalsAndDirectories(tmux: Bool, sameDirectory: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let states: [PetState] = [.working, .waiting, .idle]
        let events = ["PreToolUse", "PermissionRequest", "Stop"]
        for provider in Provider.allCases {
            let sessions = (0..<2).map { index in
                AgentSession(provider: provider, pid: Int32(100 + index), startTime: 100,
                             cwd: sameDirectory ? "/project" : "/project-\(index)",
                             launchSessionId: provider == .codex ? "thread-\(index)" : nil,
                             tmux: tmux ? TmuxLocation(socketPath: "/tmp/test-socket", paneId: "%\(index)") : nil)
            }
            for step in states.indices {
                for index in sessions.indices {
                    let stateIndex = (step + index) % states.count
                    let session = sessions[index]
                    let payload: [String: Any] = ["session_id": "thread-\(index)", "cwd": session.cwd,
                                                  "hook_event_name": events[stateIndex]]
                    let record = try #require(HookEvents.record(
                        provider: provider, payload: payload,
                        agent: provider == .codex ? (10, 50) : (session.pid, session.startTime),
                        now: Date(timeIntervalSince1970: Double(101 + step))))
                    _ = try HookEvents.write(record, to: directory)
                }
                let merged = SessionMerger.merge(sessions, records: HookEvents.readAll(from: directory))
                for index in merged.indices {
                    #expect(merged[index].state == states[(step + index) % states.count])
                    #expect(merged[index].sessionId == "thread-\(index)")
                    #expect(merged[index].pid == sessions[index].pid)
                    #expect(merged[index].tmux == sessions[index].tmux)
                }
            }
        }
    }

    @Test(arguments: [false, true], [false, true])
    func plainCodexOnlyMatchesWhenDirectoryIsUnambiguous(tmux: Bool, sameDirectory: Bool) {
        let sessions = (0..<2).map { index in
            AgentSession(provider: .codex, pid: Int32(100 + index), startTime: 100,
                         cwd: sameDirectory ? "/project" : "/project-\(index)",
                         tmux: tmux ? TmuxLocation(socketPath: "/tmp/test-socket", paneId: "%\(index)") : nil)
        }
        let records = sessions.enumerated().map { index, session in
            HookRecord(provider: .codex, sessionId: "thread-\(index)", state: index == 0 ? .working : .idle,
                       event: index == 0 ? "PreToolUse" : "Stop", cwd: session.cwd,
                       pid: 10, pidStart: 50, updatedAt: 101)
        }
        let merged = SessionMerger.merge(sessions, records: records)
        #expect(merged.map(\.state) == (sameDirectory ? [.unknown, .unknown] : [.working, .idle]))
    }
}
