import CoreGraphics
import Foundation
import Testing
@testable import DeskPetsCore

@Suite struct PetPlacementTests {
    private let laptop = CGRect(x: 0, y: 40, width: 1440, height: 835)
    private let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

    @Test func visiblePetsKeepTheirPositionOnAnyScreen() {
        for origin in [CGPoint(x: 100, y: 100), CGPoint(x: 1800, y: 200)] {
            let pet = CGRect(origin: origin, size: CGSize(width: 128, height: 128))
            #expect(PetPlacement.visibleOrigin(for: pet, screens: [laptop, external]) == origin)
        }
        let left = CGRect(x: -1920, y: -400, width: 1920, height: 1080)
        let pet = CGRect(x: -1800, y: -200, width: 128, height: 128)
        #expect(PetPlacement.visibleOrigin(for: pet, screens: [laptop, left]) == pet.origin)
    }

    @Test func disconnectedDisplayReturnsPetToVisibleDesktop() {
        let pet = CGRect(x: 1698, y: 1567, width: 128, height: 128)
        let origin = PetPlacement.visibleOrigin(for: pet, screens: [laptop])
        #expect(origin == CGPoint(x: 1312, y: 747))
        #expect(laptop.contains(CGRect(origin: origin, size: pet.size)))
    }

    @Test func resizedAndPartlyHiddenPetsAvoidDockAndMenuBar() {
        let pet = CGRect(x: 1350, y: 10, width: 256, height: 256)
        #expect(PetPlacement.visibleOrigin(for: pet, screens: [laptop]) == CGPoint(x: 1184, y: 40))
    }

    @Test func choosesNearestDisplayAndToleratesNoScreensDuringTransition() {
        let pet = CGRect(x: 3500, y: 500, width: 128, height: 128)
        #expect(PetPlacement.visibleOrigin(for: pet, screens: [laptop, external]) == CGPoint(x: 3232, y: 500))
        #expect(PetPlacement.visibleOrigin(for: pet, screens: []) == pet.origin)
    }
}
