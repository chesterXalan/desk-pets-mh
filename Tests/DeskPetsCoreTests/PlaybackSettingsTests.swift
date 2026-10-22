import Foundation
import Testing
@testable import DeskPetsCore

@Suite struct PlaybackSettingsTests {
    @Test func savesDurationWithoutLosingBindings() throws {
        let binding = PetBinding(provider: .codex, cwd: "/project", character: "轟龍", pid: 42, pidStart: 100)
        let config = AppConfig(petSize: 128, bindings: [binding], animationDuration: 1.2)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
        #expect(decoded.animationDuration == 1.2)
    }

    @Test(arguments: ["null", "0", "-1", "20", "\"invalid\""])
    func invalidDurationKeepsOtherSettings(value: String) throws {
        let json = "{\"petSize\":128,\"showPets\":false,\"animationDuration\":\(value)}"
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        #expect(config.animationDuration == nil)
        #expect(config.petSize == 128 && !config.showPets)
    }

    @Test func olderConfigKeepsOriginalTiming() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data("{\"petSize\":64}".utf8))
        #expect(config.animationDuration == nil)
        #expect(config.petSize == 64)
    }
}
