import Foundation
import Testing
@testable import DeskPetsCore

@Suite struct TmuxTests {
    @Test func parsesEnvironmentWithoutLosingSocketCommas() {
        let location = TmuxLocation.from(environment: ["TMUX": "/tmp/pets, work/socket,123,1", "TMUX_PANE": "%42"])
        #expect(location == TmuxLocation(socketPath: "/tmp/pets, work/socket", paneId: "%42"))
        #expect(TmuxLocation.from(environment: [:]) == nil)
        #expect(TmuxLocation.from(environment: ["TMUX": "relative,123,1", "TMUX_PANE": "%42"]) == nil)
        #expect(TmuxLocation.from(environment: ["TMUX": "/tmp/socket,123,1", "TMUX_PANE": "%42;kill-server"]) == nil)
        #expect(TmuxLocation.from(environment: ["TMUX": "/tmp/socket,123,1", "TMUX_PANE": "%"]) == nil)
    }

    @Test func prefersMatchingSessionAndSkipsControlClients() {
        let location = TmuxLocation(socketPath: "/tmp/socket", paneId: "%42")
        var calls: [[String]] = []
        let clients = TmuxControl.clients(for: location) { _, args in
            calls.append(args)
            if args.contains("display-message") { return Data("$1\n".utf8) }
            return Data("""
            10\t/dev/ttys001\t$2\t500\t0
            11\t/dev/ttys002\t$1\t100\t0
            12\t/dev/ttys003\t$1\t200\t0
            13\t\t$1\t900\t1
            14\t/dev/ttys004\t$1\t950\t1
            malformed
            """.utf8)
        }
        #expect(clients.map(\.pid) == [12, 11, 10])
        #expect(calls.first == ["-S", "/tmp/socket", "display-message", "-p", "-t", "%42", "#{session_id}"])
        #expect(calls.count == 2)
    }

    @Test func missingPaneDoesNotChooseAnotherSession() {
        let location = TmuxLocation(socketPath: "/tmp/socket", paneId: "%42")
        var calls = 0
        let clients = TmuxControl.clients(for: location) { _, _ in calls += 1; return nil }
        #expect(clients.isEmpty)
        #expect(calls == 1)
    }

    @Test func focusesExactClientAndPaneWithoutUpdatingEnvironment() {
        let location = TmuxLocation(socketPath: "/tmp/pets work/socket", paneId: "%42")
        let client = TmuxClient(pid: 12, tty: "/dev/ttys003", sessionId: "$1", activity: 200)
        var calls: [[String]] = []
        let ok = TmuxControl.focus(location, client: client) { _, args in
            calls.append(args)
            return Data()
        }
        #expect(ok)
        #expect(calls == [["-S", "/tmp/pets work/socket", "switch-client", "-E", "-c", "/dev/ttys003", "-t", "%42"]])
        #expect(!TmuxControl.focus(location, client: client) { _, _ in nil })
    }
}
