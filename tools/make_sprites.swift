// Generates the built-in pixel-art characters (cat, ghost, bread) as GIFs.
// Usage: swift tools/make_sprites.swift Resources/Characters
// The art is drawn entirely by this script and ships under the project's MIT license.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 32

struct Canvas {
    var pixels = [UInt32](repeating: 0, count: size * size)

    mutating func set(_ x: Int, _ y: Int, _ color: UInt32) {
        guard x >= 0, y >= 0, x < size, y < size else { return }
        pixels[y * size + x] = color
    }

    func get(_ x: Int, _ y: Int) -> UInt32 {
        guard x >= 0, y >= 0, x < size, y < size else { return 0 }
        return pixels[y * size + x]
    }

    mutating func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: UInt32) {
        for yy in y..<(y + h) { for xx in x..<(x + w) { set(xx, yy, color) } }
    }

    mutating func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ color: UInt32) {
        for y in 0..<size {
            for x in 0..<size {
                let dx = (Double(x) + 0.5 - cx) / rx
                let dy = (Double(y) + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1 { set(x, y, color) }
            }
        }
    }

    /// Paints every empty pixel that touches the sprite with the outline color.
    mutating func outline(_ color: UInt32) {
        let snapshot = self
        for y in 0..<size {
            for x in 0..<size where snapshot.get(x, y) == 0 {
                if [(1, 0), (-1, 0), (0, 1), (0, -1)].contains(where: { snapshot.get(x + $0.0, y + $0.1) != 0 }) {
                    set(x, y, color)
                }
            }
        }
    }

    /// Draws a small pattern; "#" uses `ink`, "." is skipped.
    mutating func stamp(_ rows: [String], _ x: Int, _ y: Int, _ ink: UInt32) {
        for (dy, row) in rows.enumerated() {
            for (dx, char) in row.enumerated() where char == "#" { set(x + dx, y + dy, ink) }
        }
    }

    func image() -> CGImage {
        // Pixels are 0xRRGGBBAA; CGImage wants RGBA bytes.
        var bytes = [UInt8]()
        bytes.reserveCapacity(size * size * 4)
        for pixel in pixels {
            bytes += [UInt8(pixel >> 24 & 0xff), UInt8(pixel >> 16 & 0xff), UInt8(pixel >> 8 & 0xff), UInt8(pixel & 0xff)]
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}

func writeGIF(_ frames: [(Canvas, Double)], to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
    let loop = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
    CGImageDestinationSetProperties(destination, loop)
    for (canvas, delay) in frames {
        let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay,
                                                          kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary
        CGImageDestinationAddImage(destination, canvas.image(), properties)
    }
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
    print("wrote \(url.path)")
}

// MARK: - Palette

let ink: UInt32 = 0x2B_1D_2E_FF
let white: UInt32 = 0xFF_FF_FF_FF
let pink: UInt32 = 0xF2_8C_A8_FF
let orange: UInt32 = 0xF0_9A_3E_FF
let darkOrange: UInt32 = 0xC8_6A_22_FF
let cream: UInt32 = 0xFF_E8_C8_FF
let laptop: UInt32 = 0xB8_C0_CC_FF
let laptopDark: UInt32 = 0x7A_84_94_FF
let glow: UInt32 = 0x7F_E0_FF_FF
let ghostBody: UInt32 = 0xF4_F0_FF_FF
let ghostShade: UInt32 = 0xD8_CF_F5_FF
let accent: UInt32 = 0xFF_9F_1C_FF
let blue: UInt32 = 0x4C_8D_F6_FF
let breadBody: UInt32 = 0xF5_E6_BE_FF
let breadShade: UInt32 = 0xDE_C6_92_FF
let breadFeet: UInt32 = 0x9C_5E_32_FF
let breadInk: UInt32 = 0x5C_3B_24_FF

func bubble(_ canvas: inout Canvas, mark: String) {
    canvas.rect(23, 1, 8, 8, white)
    canvas.rect(24, 0, 6, 10, white)
    canvas.set(23, 10, white)
    canvas.set(24, 9, white)
    if mark == "!" {
        canvas.rect(26, 2, 2, 4, accent)
        canvas.rect(26, 7, 2, 1, accent)
    } else {
        canvas.stamp(["####", "#..#", "...#", "..#.", "....", "..#."], 25, 2, blue)
    }
}

// MARK: - Cat

func cat(tail: Int, blink: Bool = false, dy: Int = 0, lookUp: Bool = false, paws: (Int, Int)? = nil) -> Canvas {
    var c = Canvas()
    // Tail curls up on the right; `tail` shifts its tip.
    let tailPath = [(24, 28), (25, 27), (26, 26), (26, 25), (27, 24), (27, 23), (27 + tail, 22), (27 + tail, 21)]
    for (x, y) in tailPath {
        c.rect(x, y + dy, 2, 1, orange)
    }
    c.set(27 + tail, 20 + dy, darkOrange)
    c.set(28 + tail, 20 + dy, darkOrange)
    c.ellipse(16, 25 + Double(dy), 8.5, 6.5, orange)
    c.ellipse(16, 26 + Double(dy), 4.5, 4.5, cream)
    c.ellipse(16, 14 + Double(dy), 7.5, 6.5, orange)
    // Ears.
    c.stamp(["#", "##", "###"], 9, 7 + dy, orange)
    c.stamp(["..#", ".##", "###"], 20, 7 + dy, orange)
    c.set(10, 9 + dy, pink)
    c.set(21, 9 + dy, pink)
    // Stripes.
    c.rect(15, 8 + dy, 2, 2, darkOrange)
    c.rect(9, 14 + dy, 2, 1, darkOrange)
    c.rect(21, 14 + dy, 2, 1, darkOrange)
    c.rect(10, 24 + dy, 2, 1, darkOrange)
    c.rect(20, 24 + dy, 2, 1, darkOrange)
    // Face.
    let eyeY = (lookUp ? 11 : 12) + dy
    if blink {
        c.rect(12, eyeY + 1, 2, 1, ink)
        c.rect(18, eyeY + 1, 2, 1, ink)
    } else {
        c.rect(12, eyeY, 2, 2, ink)
        c.rect(18, eyeY, 2, 2, ink)
        c.set(12, eyeY, white)
        c.set(18, eyeY, white)
    }
    c.set(15, 15 + dy, pink)
    c.set(16, 15 + dy, pink)
    c.stamp(["#..#", ".##."], 14, 16 + dy, ink)
    c.set(11, 15 + dy, pink)
    c.set(20, 15 + dy, pink)
    if let paws {
        c.rect(11, 26 - paws.0, 3, 2, cream)
        c.rect(18, 26 - paws.1, 3, 2, cream)
    } else {
        c.rect(11, 29 + dy, 3, 2, cream)
        c.rect(18, 29 + dy, 3, 2, cream)
    }
    c.outline(ink)
    return c
}

func catWorking(_ frame: Int) -> Canvas {
    let paws = [(1, 0), (0, 1), (1, 0), (0, 0)][frame]
    var c = cat(tail: frame % 2, dy: 0, paws: paws)
    // Laptop seen from behind the screen, keyboard in front of the paws.
    c.rect(8, 28, 16, 3, laptop)
    c.rect(8, 31, 16, 1, laptopDark)
    c.rect(10, 22, 12, 6, laptopDark)
    c.rect(11, 23, 10, 4, laptop)
    c.rect(15, 24, 2, 2, frame % 2 == 0 ? glow : white)
    // Typing sparks.
    let sparks = [[(5, 20)], [(4, 18), (27, 19)], [(6, 17)], [(26, 17)]][frame]
    for (x, y) in sparks { c.set(x, y, glow) }
    return c
}

// MARK: - Ghost

func ghost(dy: Int, dx: Int = 0, phase: Int, mouth: Bool = false, focused: Bool = false) -> Canvas {
    var c = Canvas()
    let top = 5 + dy
    c.ellipse(16 + Double(dx), Double(top) + 9, 9.5, 9.5, ghostBody)
    c.rect(7 + dx, top + 9, 19, 11, ghostBody)
    // Scalloped hem that ripples with `phase`.
    for x in 7...25 {
        let wave = ((x + phase) / 3) % 2 == 0 ? 0 : 2
        c.rect(x + dx, top + 20, 1, 3 - wave, ghostBody)
        c.set(x + dx, top + 19, (x + phase) % 6 == 0 ? ghostShade : ghostBody)
    }
    c.rect(22 + dx, top + 6, 2, 12, ghostShade)
    // Face.
    let eyeHeight = focused ? 2 : 3
    c.rect(11 + dx, top + 8, 2, eyeHeight, ink)
    c.rect(19 + dx, top + 8, 2, eyeHeight, ink)
    c.set(11 + dx, top + 8, white)
    c.set(19 + dx, top + 8, white)
    c.rect(9 + dx, top + 12, 2, 1, pink)
    c.rect(21 + dx, top + 12, 2, 1, pink)
    if mouth {
        c.stamp([".##.", "#..#", ".##."], 14 + dx, top + 12, ink)
    } else {
        c.stamp(["#..#", ".##."], 14 + dx, top + 12, ink)
    }
    c.outline(ink)
    return c
}

// MARK: - Bread

/// A croissant plush: five puffy lobes, tiny face, brown feet. `squash` flattens it a pixel.
func bread(dy: Int = 0, squash: Int = 0, blink: Bool = false, feet: (Int, Int) = (0, 0)) -> Canvas {
    var c = Canvas()
    let y = Double(dy + squash)
    let s = Double(squash)
    // Feet first so the body overlaps their tops.
    c.rect(10, 26 - feet.0, 4, 3, breadFeet)
    c.rect(18, 26 - feet.1, 4, 3, breadFeet)
    // Lobes from the curled tips inwards: (center x, center y, rx, ry).
    let lobes: [(Double, Double, Double, Double)] = [
        (4, 21, 3, 4.5), (28, 21, 3, 4.5),
        (8.5, 18.5, 4.5, 6.5), (23.5, 18.5, 4.5, 6.5),
        (16, 17, 7, 8.5),
    ]
    for (cx, cy, rx, ry) in lobes {
        c.ellipse(16 + (cx - 16) * (1 + s * 0.04), cy + y, rx, ry - s, breadBody)
    }
    // A flat underside like the plush sitting on a pillow.
    c.rect(5, 19 + dy + squash, 22, 6 - squash, breadBody)
    c.outline(breadInk)
    // Dents and short seams where the lobes meet, so the silhouette reads as a croissant.
    let top = dy + squash
    for (x, y0, len) in [(6, 15, 3), (9, 11, 5), (22, 11, 5), (25, 15, 3)] {
        c.set(x, y0 + top, breadInk)
        c.rect(x, y0 + top + 1, 1, len - squash, breadShade)
    }
    // The little stitched smile on top.
    c.stamp(["#..#", ".##."], 14, 11 + top, breadShade)
    // Face.
    let eyeY = 16 + top
    if blink {
        c.rect(13, eyeY + 1, 2, 1, breadInk)
        c.rect(17, eyeY + 1, 2, 1, breadInk)
    } else {
        c.rect(13, eyeY, 2, 2, breadInk)
        c.rect(17, eyeY, 2, 2, breadInk)
        c.set(13, eyeY, white)
        c.set(17, eyeY, white)
    }
    c.set(15, eyeY + 2, breadInk)
    c.set(16, eyeY + 2, breadInk)
    // "Bread" embroidery, abbreviated to a squiggle.
    c.stamp(["#.#.#", ".#.#."], 13, eyeY + 4, breadShade)
    return c
}

// MARK: - Output

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Characters", isDirectory: true)

writeGIF([
    (cat(tail: 0), 0.3), (cat(tail: 1), 0.3), (cat(tail: 2), 0.3),
    (cat(tail: 1), 0.3), (cat(tail: 0, blink: true), 0.15), (cat(tail: 0), 0.6),
], to: root.appendingPathComponent("cat/idle.gif"))
writeGIF((0..<4).map { (catWorking($0), 0.12) }, to: root.appendingPathComponent("cat/working.gif"))
writeGIF((0..<4).map { frame in
    var c = cat(tail: [0, 2, 0, 2][frame], dy: frame % 2 == 0 ? 0 : -1, lookUp: true)
    if frame != 3 { bubble(&c, mark: "!") }
    return (c, 0.22)
}, to: root.appendingPathComponent("cat/waiting.gif"))

writeGIF((0..<4).map { (ghost(dy: [0, 1, 2, 1][$0], phase: $0), 0.22) },
         to: root.appendingPathComponent("ghost/idle.gif"))
writeGIF((0..<4).map { frame in
    var c = ghost(dy: [0, 1, 0, 1][frame], phase: frame * 2, focused: true)
    for dot in 0..<3 {
        c.rect(9 + dot * 6, 1, 3, 3, dot <= frame - 1 || frame == 0 && dot == 0 ? accent : ghostShade)
    }
    return (c, 0.14)
}, to: root.appendingPathComponent("ghost/working.gif"))
writeGIF((0..<4).map { frame in
    var c = ghost(dy: 1, dx: [-1, 0, 1, 0][frame], phase: frame, mouth: true)
    if frame != 3 { bubble(&c, mark: "?") }
    return (c, 0.22)
}, to: root.appendingPathComponent("ghost/waiting.gif"))

writeGIF([
    (bread(), 0.4), (bread(squash: 1), 0.4), (bread(), 0.4),
    (bread(squash: 1), 0.4), (bread(blink: true), 0.15), (bread(), 0.6),
], to: root.appendingPathComponent("bread/idle.gif"))
writeGIF((0..<4).map { frame in
    var c = bread(dy: frame % 2 == 0 ? 0 : -1, feet: [(1, 0), (0, 0), (0, 1), (0, 0)][frame])
    // Fresh-from-the-oven steam.
    let steam = [[(8, 4), (9, 3)], [(9, 2), (22, 4)], [(23, 3), (8, 1)], [(23, 1), (14, 2)]][frame]
    for (x, y) in steam { c.rect(x, y, 1, 2, breadShade) }
    return (c, 0.14)
}, to: root.appendingPathComponent("bread/working.gif"))
writeGIF((0..<4).map { frame in
    var c = bread(dy: frame % 2 == 0 ? 0 : -1, squash: frame == 3 ? 1 : 0)
    if frame != 3 { bubble(&c, mark: "?") }
    return (c, 0.22)
}, to: root.appendingPathComponent("bread/waiting.gif"))
