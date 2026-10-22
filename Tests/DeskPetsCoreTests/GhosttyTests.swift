import Foundation
import Testing
@testable import DeskPetsCore

@Suite struct GhosttyTests {
    @Test func selectsUniqueDirectoryAcrossTabsAndSplits() throws {
        let expected = GhosttyTerminal(id: UUID(), directory: "/tmp/pets/project")
        let terminals = [GhosttyTerminal(id: UUID(), directory: "/tmp/other"), expected]
        #expect(try GhosttyControl.target(directory: "/tmp/pets/./project/", terminals: terminals) == expected)
    }

    @Test func neverPicksFirstWhenDirectoriesAreAmbiguous() {
        let terminals = [GhosttyTerminal(id: UUID(), directory: "/tmp/project"),
                         GhosttyTerminal(id: UUID(), directory: "/tmp/project/")]
        #expect(throws: GhosttyFocusError.ambiguous) {
            try GhosttyControl.target(directory: "/tmp/project", terminals: terminals)
        }
    }

    @Test func missingOrUnreportedDirectoryDoesNotSelectAnotherTab() {
        let terminals = [GhosttyTerminal(id: UUID(), directory: ""),
                         GhosttyTerminal(id: UUID(), directory: "/tmp/other")]
        for directory in ["/tmp/missing", "", "relative"] {
            #expect(throws: GhosttyFocusError.notFound) {
                try GhosttyControl.target(directory: directory, terminals: terminals)
            }
        }
        #expect(throws: GhosttyFocusError.notFound) {
            try GhosttyControl.target(directory: "/tmp/other", terminals: [])
        }
    }

    @Test func matchesSymlinkAndLiteralSpecialCharacters() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let real = root.appendingPathComponent("魔物 \"quoted\" \\ backslash\nline")
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        let expected = GhosttyTerminal(id: UUID(), directory: real.path)
        #expect(try GhosttyControl.target(directory: alias.path, terminals: [expected]) == expected)
    }
}
