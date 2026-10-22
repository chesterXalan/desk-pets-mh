import Foundation
import Testing
@testable import DeskPetsCore

@Suite struct AutomaticPetTests {
    private let characters = ["zinogre", "mizutsune", "nargacuga"]

    @Test func newDirectoryGetsOneStableRandomChoice() {
        var config = AppConfig()
        let session = AgentSession(provider: .codex, pid: 1, startTime: 100, cwd: "/project")
        var choices = 0
        let choose: ([String]) -> String? = { candidates in
            choices += 1
            return candidates.last
        }
        _ = BindingResolver.resolve(&config, sessions: [session], characters: characters, choose: choose)
        let first = config
        _ = BindingResolver.resolve(&config, sessions: [session], characters: characters, choose: choose)
        #expect(choices == 1)
        #expect(config == first)
        #expect(config.directoryPets[session.cwd]?.character == "nargacuga")
    }

    @Test func lastManualChoiceSurvivesClosingAndChangingProvider() throws {
        var config = AppConfig()
        let sessions = [AgentSession(provider: .claude, pid: 1, startTime: 100, cwd: "/project"),
                        AgentSession(provider: .codex, pid: 2, startTime: 200, cwd: "/project")]
        _ = BindingResolver.resolve(&config, sessions: sessions, characters: characters, choose: { $0.first })
        #expect(config.bindings.map(\.character) == ["zinogre", "mizutsune"])
        #expect(config.directoryPets["/project"]?.character == "zinogre")
        config.bindings[1].character = "nargacuga"
        config.bindings[1].x = 50
        config.rememberCharacter(from: config.bindings[1])
        _ = BindingResolver.resolve(&config, sessions: [], characters: characters)
        #expect(config.bindings.isEmpty)
        config = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        let restarted = AgentSession(provider: .codex, pid: 3, startTime: 300, cwd: "/project")
        _ = BindingResolver.resolve(&config, sessions: [restarted], characters: characters, choose: { _ in nil })
        #expect(config.bindings.first?.character == "nargacuga")
        #expect(config.bindings.first?.x == 50)
    }

    @Test func randomExtrasAvoidDuplicatesUntilCharactersRunOut() {
        var config = AppConfig(directoryPets: ["/project": DirectoryPetPreference(character: "mizutsune")])
        let sessions = (1...5).map { AgentSession(provider: .codex, pid: Int32($0), startTime: Double($0), cwd: "/project") }
        _ = BindingResolver.resolve(&config, sessions: sessions, characters: characters, choose: { $0.first })
        #expect(config.bindings.count == sessions.count)
        #expect(config.bindings.first?.character == "mizutsune")
        #expect(Set(config.bindings.prefix(3).map(\.character)).count == 3)
        #expect(config.directoryPets["/project"]?.character == "mizutsune")
    }

    @Test func randomChoicesAvoidPetsInOtherDirectories() {
        let active = PetBinding(provider: .claude, cwd: "/first", character: "zinogre", pid: 1, pidStart: 100, x: 12, y: 34)
        var config = AppConfig(bindings: [active])
        let sessions = [AgentSession(provider: .claude, pid: 1, startTime: 100, cwd: "/first"),
                        AgentSession(provider: .codex, pid: 2, startTime: 200, cwd: "/second")]
        _ = BindingResolver.resolve(&config, sessions: sessions, characters: characters, choose: { $0.first })
        #expect(config.bindings[0] == active)
        #expect(config.bindings[1].character == "mizutsune")
    }

    @Test func hiddenSessionStaysHiddenWithoutForgettingDirectoryChoice() throws {
        var config = AppConfig(directoryPets: ["/project": DirectoryPetPreference(character: "zinogre")])
        let session = AgentSession(provider: .codex, pid: 1, startTime: 100, cwd: "/project")
        _ = BindingResolver.resolve(&config, sessions: [session], characters: characters)
        config.bindings[0].character = ""
        config = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        _ = BindingResolver.resolve(&config, sessions: [session], characters: characters)
        #expect(config.bindings[0].character.isEmpty)
        #expect(config.directoryPets["/project"]?.character == "zinogre")
        let restarted = AgentSession(provider: .codex, pid: 2, startTime: 200, cwd: "/project")
        _ = BindingResolver.resolve(&config, sessions: [restarted], characters: characters)
        #expect(config.bindings.count == 1 && config.bindings[0].character == "zinogre")
    }

    @Test func removedCharacterGetsReplacedAndEmptyLibraryIsSafe() {
        var config = AppConfig(bindings: [PetBinding(provider: .codex, cwd: "/project", character: "removed",
                                                    pid: 1, pidStart: 100, x: 50, y: 60)],
                               directoryPets: ["/project": DirectoryPetPreference(character: "removed")])
        let session = AgentSession(provider: .codex, pid: 1, startTime: 100, cwd: "/project")
        _ = BindingResolver.resolve(&config, sessions: [session], characters: characters, choose: { $0.first })
        #expect(config.bindings[0].character == "zinogre" && config.bindings[0].x == 50)
        #expect(config.directoryPets["/project"]?.character == "zinogre")
        _ = BindingResolver.resolve(&config, sessions: [session], characters: [])
        #expect(config.bindings.isEmpty)
    }
}
