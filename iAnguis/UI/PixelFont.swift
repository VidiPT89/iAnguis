import SwiftUI

/// A 5×7 dot-matrix font with room above for Portuguese accents and below for the cedilla.
enum PixelFont {
    static let glyphHeight = 7
    /// Rows above the glyph for accents, and one below for the cedilla.
    static let top = 2
    static let height = 10

    private static let glyphs: [Character: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "i": ["..#..", ".....", ".##..", "..#..", "..#..", "..#..", ".###."],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "×": [".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "....."],
        "▶": ["#....", "##...", "###..", "####.", "###..", "##...", "#...."],
        "◀": ["....#", "...##", "..###", ".####", "..###", "...##", "....#"],
        "♥": [".....", ".#.#.", "#####", "#####", ".###.", "..#..", "....."],
    ]

    private static let marks: [Unicode.Scalar: [String]] = [
        "\u{0301}": ["...#.", "..#.."],
        "\u{0300}": [".#...", "..#.."],
        "\u{0303}": [".#..#", "#.##."],
        "\u{0302}": ["..#..", ".#.#."],
    ]

    /// Lit pixel coordinates for a string, and its width in pixels.
    static func layout(_ text: String) -> (width: Int, pixels: [(Int, Int)]) {
        var pixels: [(Int, Int)] = []
        var x = 0
        for character in text {
            if character == " " { x += 4; continue }
            let decomposed = String(character).decomposedStringWithCanonicalMapping.unicodeScalars
            guard let baseScalar = decomposed.first else { continue }
            let base = Character(baseScalar)
            guard let rows = glyphs[base] ?? glyphs[Character(base.uppercased())] else { x += 6; continue }
            stamp(rows, x: x, y: top, into: &pixels)
            for mark in decomposed.dropFirst() {
                if let accent = marks[mark] { stamp(accent, x: x, y: 0, into: &pixels) }
                if mark == "\u{0327}" { pixels.append((x + 2, top + glyphHeight)); pixels.append((x + 1, top + glyphHeight)) }
            }
            x += 6
        }
        return (max(0, x - 1), pixels)
    }

    private static func stamp(_ rows: [String], x: Int, y: Int, into pixels: inout [(Int, Int)]) {
        for (row, line) in rows.enumerated() {
            for (column, mark) in line.enumerated() where mark == "#" { pixels.append((x + column, y + row)) }
        }
    }
}

/// Dot-matrix text as drawn by an old monochrome LCD.
struct LCDText: View {
    let text: String
    var pixel: CGFloat = 2
    var color: Color = .black

    init(_ text: String, pixel: CGFloat = 2, color: Color = .black) {
        self.text = text
        self.pixel = pixel
        self.color = color
    }

    var body: some View {
        let layout = PixelFont.layout(text)
        Canvas { context, _ in
            var path = Path()
            let dot = pixel * 0.86
            for (x, y) in layout.pixels {
                path.addRect(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: dot, height: dot))
            }
            context.fill(path, with: .color(color))
        }
        .frame(width: CGFloat(layout.width) * pixel, height: CGFloat(PixelFont.height) * pixel)
        .accessibilityElement()
        .accessibilityLabel(text)
    }
}

/// A small pixel-art icon from rows of "#" and ".".
struct PixelIcon: View {
    let rows: [String]
    var pixel: CGFloat = 2
    var color: Color = .black

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            for (y, line) in rows.enumerated() {
                for (x, mark) in line.enumerated() where mark == "#" {
                    path.addRect(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel * 0.86, height: pixel * 0.86))
                }
            }
            context.fill(path, with: .color(color))
        }
        .frame(width: CGFloat(rows.first?.count ?? 0) * pixel, height: CGFloat(rows.count) * pixel)
        .accessibilityHidden(true)
    }

    static let signal = ["......#", "....#.#", "..#.#.#", "#.#.#.#", "#.#.#.#"]
    static let battery = ["########.", "#.##.##.#", "#.##.##.#", "#.##.##.#", "########."]
}
