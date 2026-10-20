// Generates Resources/AppIcon.icns from the first frame of the bundled ghost.
// Run: swift tools/make_icon.swift
import AppKit
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let gif = root.appendingPathComponent("Resources/Characters/ghost/idle.gif")
guard let source = CGImageSourceCreateWithURL(gif as CFURL, nil),
      let ghost = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("cannot read \(gif.path)")
}

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // macOS icon grid: 824/1024 rounded square, centered.
    let inset = s * 100 / 1024
    let tile = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = tile.width * 0.225
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    let colors = [CGColor(srgbRed: 0.42, green: 0.36, blue: 0.78, alpha: 1),
                  CGColor(srgbRed: 0.16, green: 0.13, blue: 0.34, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // Keep the pixels crisp: integer scale, nearest-neighbour.
    let scale = max(1, Int(tile.width * 0.72) / ghost.width)
    let w = CGFloat(ghost.width * scale), h = CGFloat(ghost.height * scale)
    ctx.interpolationQuality = .none
    ctx.draw(ghost, in: CGRect(x: ((s - w) / 2).rounded(), y: ((s - h) / 2).rounded(), width: w, height: h))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try iconutil.run()
iconutil.waitUntilExit()
print("wrote \(out.path)")
