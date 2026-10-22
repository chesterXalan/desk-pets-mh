import CoreGraphics
import Foundation

public enum PetPlacement {
    /// 保留可見位置；螢幕拔除或縮小時，移回距離最近的可用範圍。
    public static func visibleOrigin(for pet: CGRect, screens: [CGRect]) -> CGPoint {
        if screens.contains(where: { $0.contains(pet) }) { return pet.origin }
        return screens.map { screen in
            CGPoint(x: min(max(pet.minX, screen.minX), max(screen.minX, screen.maxX - pet.width)),
                    y: min(max(pet.minY, screen.minY), max(screen.minY, screen.maxY - pet.height)))
        }.min { left, right in
            hypot(left.x - pet.minX, left.y - pet.minY) < hypot(right.x - pet.minX, right.y - pet.minY)
        } ?? pet.origin
    }
}
