// Renders the 1024×1024 app icon: a dot-matrix snake on a green LCD inside the orange cover.
// Run from the repository root: swift scripts/render-icon.swift
import AppKit

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Cover gradient
let shell = CGGradient(colorsSpace: space, colors: [color(0xF5873A), color(0xC4500F)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(shell, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

// Bezel and LCD
let bezel = CGRect(x: 112, y: 112, width: 800, height: 800)
ctx.setFillColor(color(0x1C1C20))
ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: 120, cornerHeight: 120, transform: nil))
ctx.fillPath()
let screen = bezel.insetBy(dx: 44, dy: 44)
let lcd = CGGradient(colorsSpace: space, colors: [color(0xBCD47C), color(0x9DB862)] as CFArray, locations: [0, 1])!
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 80, cornerHeight: 80, transform: nil))
ctx.clip()
ctx.drawLinearGradient(lcd, start: CGPoint(x: 0, y: screen.maxY), end: CGPoint(x: 0, y: screen.minY), options: [])

// Dot matrix: 21×21 dots
let dots = 21
let pitch = screen.width / CGFloat(dots + 2)
let dot = pitch * 0.84
let ink = color(0x1F3318)
func lit(_ x: Int, _ y: Int, _ c: CGColor = ink) {
    ctx.setFillColor(c)
    ctx.fill(CGRect(x: screen.minX + pitch * CGFloat(x + 1), y: screen.maxY - pitch * CGFloat(y + 2), width: dot, height: dot))
}
for y in 0..<dots { for x in 0..<dots { lit(x, y, color(0x1F3318, 0.08)) } }

// Snake path (thick 3-dot body) winding towards the apple
let path: [(Int, Int)] = [(3, 16), (9, 16), (9, 10), (15, 10), (15, 5)]
for i in 0..<(path.count - 1) {
    let a = path[i], b = path[i + 1]
    for y in min(a.1, b.1) - 1...max(a.1, b.1) + 1 { for x in min(a.0, b.0) - 1...max(a.0, b.0) + 1 { lit(x, y) } }
}
// Head facing up with two eyes; the top corners stay dark-free for a rounded snout
for y in 2...5 { for x in 13...17 { if !((x == 13 || x == 17) && y == 2) { lit(x, y) } } }
for (x, y) in [(14, 3), (16, 3)] { lit(x, y, color(0xB0CA72)) }
// Apple
let apple = ["...#.", ".##..", "#####", "#####", ".###."]
for (row, line) in apple.enumerated() { for (col, ch) in line.enumerated() where ch == "#" { lit(4 + col, 3 + row) } }
ctx.restoreGState()

// Glass glare
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 80, cornerHeight: 80, transform: nil))
ctx.clip()
let glare = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.25), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(glare, start: CGPoint(x: screen.minX, y: screen.maxY), end: CGPoint(x: screen.midX, y: screen.midY), options: [])
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "iAnguis/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
print("Icon written")
