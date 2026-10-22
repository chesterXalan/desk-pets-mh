import Foundation
import Testing
@testable import DeskPetsCore

@Suite struct GhosttyTests {
    @Test func plainTerminalCanUseUniqueFullTitleWhenDirectoryIsStale() throws {
        let expected = GhosttyTerminal(id: UUID(), directory: "/tmp/old", title: "✳ Project task")
        let other = GhosttyTerminal(id: UUID(), directory: "/tmp/elsewhere", title: "Other task")
        #expect(try GhosttyControl.target(directory: "/tmp/current", title: "Project task",
                                          terminals: [other, expected], allowTitleFallback: true) == expected)
        #expect(throws: GhosttyFocusError.notFound) {
            try GhosttyControl.target(directory: "/tmp/current", title: "Project task", terminals: [other, expected])
        }
    }

    @Test func titleFallbackRejectsDuplicateEmptyAndPartialTitles() {
        let first = GhosttyTerminal(id: UUID(), directory: "/tmp/a", title: "Project task")
        let second = GhosttyTerminal(id: UUID(), directory: "/tmp/b", title: "⠂ Project task")
        #expect(throws: GhosttyFocusError.ambiguous) {
            try GhosttyControl.target(directory: "/tmp/current", title: "Project task",
                                       terminals: [first, second], allowTitleFallback: true)
        }
        for title in ["", "Project", "Different task"] {
            #expect(throws: GhosttyFocusError.notFound) {
                try GhosttyControl.target(directory: "/tmp/current", title: title,
                                           terminals: [first], allowTitleFallback: true)
            }
        }
    }

    @Test(arguments: ["✳ Monster project", "⠂ Monster project", "⠋ Monster project  "])
    func distinguishesSameDirectoryByCompleteSessionTitle(_ terminalTitle: String) throws {
        let expected = GhosttyTerminal(id: UUID(), directory: "/tmp/project", title: terminalTitle)
        let terminals = [GhosttyTerminal(id: UUID(), directory: "/tmp/project", title: "Other project"), expected]
        #expect(try GhosttyControl.target(directory: "/tmp/project", title: "Monster project", terminals: terminals) == expected)
    }

    @Test(arguments: ["", "⠂", "Monster", "Missing project"])
    func emptyOrPartialTitlesNeverChooseAnArbitraryTab(_ title: String) {
        let terminals = [GhosttyTerminal(id: UUID(), directory: "/tmp/project", title: "Monster project"),
                         GhosttyTerminal(id: UUID(), directory: "/tmp/project", title: "Other project")]
        #expect(throws: GhosttyFocusError.ambiguous) {
            try GhosttyControl.target(directory: "/tmp/project", title: title, terminals: terminals)
        }
    }

    @Test func duplicateNormalizedTitlesRemainAmbiguous() {
        let terminals = [GhosttyTerminal(id: UUID(), directory: "/tmp/project", title: "✳ Monster project"),
                         GhosttyTerminal(id: UUID(), directory: "/tmp/project", title: "⠂ Monster project")]
        #expect(throws: GhosttyFocusError.ambiguous) {
            try GhosttyControl.target(directory: "/tmp/project", title: "Monster project", terminals: terminals)
        }
    }

    @Test func matchingTitleInAnotherDirectoryDoesNotOverrideDirectory() throws {
        let expected = GhosttyTerminal(id: UUID(), directory: "/tmp/project", title: "✳ Monster project")
        let terminals = [GhosttyTerminal(id: UUID(), directory: "/tmp/other", title: "Monster project"), expected]
        #expect(try GhosttyControl.target(directory: "/tmp/project", title: "Monster project", terminals: terminals) == expected)
        #expect(throws: GhosttyFocusError.notFound) {
            try GhosttyControl.target(directory: "/tmp/missing", title: "Monster project", terminals: terminals)
        }
    }

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
