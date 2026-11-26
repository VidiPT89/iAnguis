import SwiftUI

/// Every board cell is drawn as 5×5 LCD dots, with one ring of dots around the playfield for the frame.
private let dotsPerCell = 5

/// Off-screen dot buffer with the slow fade of an old LCD panel.
final class LCDRaster {
    let width: Int
    let height: Int
    private(set) var level: [Float]
    private var target: [Float]
    private var lastTime = 0.0
    private var ghostSize = CGSize.zero
    private var ghost = Path()

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        level = Array(repeating: 0, count: width * height)
        target = level
    }

    func begin() { for index in target.indices { target[index] = 0 } }

    func light(_ x: Int, _ y: Int, _ value: Float = 1) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let index = y * width + x
        if value > target[index] { target[index] = value }
    }

    func fill(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ value: Float = 1) {
        for y in min(y0, y1)...max(y0, y1) { for x in min(x0, x1)...max(x0, x1) { light(x, y, value) } }
    }

    func stamp(_ rows: [String], x: Int, y: Int, facing: Direction = .right, value: Float = 1) {
        let size = rows.count - 1
        for (row, line) in rows.enumerated() {
            for (column, mark) in line.enumerated() where mark == "#" {
                let (dx, dy): (Int, Int)
                switch facing {
                case .right: (dx, dy) = (column, row)
                case .left: (dx, dy) = (size - column, row)
                case .down: (dx, dy) = (size - row, column)
                case .up: (dx, dy) = (row, size - column)
                }
                light(x + dx, y + dy, value)
            }
        }
    }

    /// Blends this frame into the displayed dots: lit dots switch on at once and fade out slowly.
    func commit(now: Double, persistence: Double) {
        let dt = lastTime == 0 ? 1 : min(1, now - lastTime)
        lastTime = now
        let decay = Float(pow(0.5, dt / persistence))
        for index in level.indices {
            let faded = level[index] * decay
            level[index] = max(target[index], faded < 0.05 ? 0 : faded)
        }
    }

    func ghostPath(dot: CGFloat, size: CGFloat) -> Path {
        let key = CGSize(width: dot, height: size)
        if key != ghostSize {
            var path = Path()
            for y in 0..<height { for x in 0..<width { path.addRect(CGRect(x: CGFloat(x) * dot, y: CGFloat(y) * dot, width: size, height: size)) } }
            ghost = path
            ghostSize = key
        }
        return ghost
    }
}

private enum Sprites {
    static let headClosed = ["####.", "###.#", "#####", "#####", "####."]
    static let headOpen = ["####.", "###.#", "##...", "###..", "####."]
    static let headBlink = ["####.", "#####", "#####", "#####", "####."]
    static let headDead = ["####.", "##.#.", "###.#", "#####", "####."]
    static let apple = [["...#.", ".##..", "#####", "#####", ".###."], ["..#..", "..##.", "#####", "#####", ".###."]]
    static let critter = [["#.#.#", ".###.", "##.##", ".###.", "#.#.#"], [".#.#.", "#####", "#.#.#", "#####", ".#.#."]]
    static let brick = ["#####", "#.#.#", "#####", "#.#.#", "#####"]
}

/// The LCD playfield: the live round, or the attract-mode demo on the menu.
struct BoardView: View {
    let model: GameModel
    let palette: LCDPalette
    let smooth: Bool
    let reduceMotion: Bool
    let active: Bool
    @State private var raster = LCDRaster(width: 18 * dotsPerCell + 2, height: 22 * dotsPerCell + 2)

    static var aspect: CGFloat { CGFloat(18 * dotsPerCell + 2) / CGFloat(22 * dotsPerCell + 2) }

    var body: some View {
        TimelineView(.animation(paused: !active)) { _ in
            Canvas(rendersAsynchronously: false) { context, size in
                draw(&context, size: size, now: ProcessInfo.processInfo.systemUptime)
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(model.game.phase == .ready ? "Demo" : "iAnguis")
        .accessibilityValue("\(model.game.score)")
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, now: Double) {
        let demo = model.game.phase == .ready
        let game = demo ? model.demo : model.game
        let previous = demo ? model.demoPrevious : model.previousSnake
        let fraction = (smooth && !reduceMotion) ? (demo ? model.demoProgress : model.progress) : 1
        let deathAge = model.overAt.map { now - $0 }

        raster.begin()
        drawFrame(game)
        for cell in game.obstacles { raster.stamp(Sprites.brick, x: origin(cell.x), y: origin(cell.y)) }
        if game.phase != .won {
            raster.stamp(Sprites.apple[Int(now * 2) % 2], x: origin(game.food.x), y: origin(game.food.y))
        }
        if let bonus = game.bonus {
            let urgent = bonus.stepsLeft <= 8
            if !urgent || Int(now * 8) % 2 == 0 {
                raster.stamp(Sprites.critter[Int(now * 4) % 2], x: origin(bonus.cell.x), y: origin(bonus.cell.y))
            }
        }
        let blinkHidden = deathAge.map { $0 < 1.0 && Int($0 * 7) % 2 == 1 } ?? false
        if !blinkHidden { drawSnake(game, previous: previous, fraction: fraction, now: now, dead: deathAge != nil) }
        if !demo { drawEffects(now: now) }
        raster.commit(now: now, persistence: reduceMotion ? 0.012 : 0.03)

        let dot = size.width / CGFloat(raster.width)
        let lit = dot * 0.84
        if let age = deathAge, age < 0.35, !reduceMotion {
            context.translateBy(x: sin(age * 70) * 4 * (1 - age / 0.35), y: 0)
        }
        context.fill(raster.ghostPath(dot: dot, size: lit), with: .color(palette.ink.opacity(0.07)))
        var strong = Path(), medium = Path(), faint = Path()
        for y in 0..<raster.height {
            for x in 0..<raster.width {
                let value = raster.level[y * raster.width + x]
                guard value > 0.05 else { continue }
                let rect = CGRect(x: CGFloat(x) * dot, y: CGFloat(y) * dot, width: lit, height: lit)
                if value > 0.7 { strong.addRect(rect) } else if value > 0.35 { medium.addRect(rect) } else { faint.addRect(rect) }
            }
        }
        let ink = palette.ink.opacity(demo ? 0.45 : 1)
        context.fill(faint, with: .color(ink.opacity(0.28)))
        context.fill(medium, with: .color(ink.opacity(0.6)))
        context.fill(strong, with: .color(ink))
    }

    private func origin(_ cell: Int) -> Int { 1 + cell * dotsPerCell }
    private func center(_ value: Double) -> Int { 1 + Int((value * Double(dotsPerCell)).rounded()) + dotsPerCell / 2 }

    /// Solid frame for walled modes, a dotted one where the snake can pass through.
    private func drawFrame(_ game: SnakeGame) {
        let w = raster.width - 1, h = raster.height - 1
        for x in 0...w where !game.mode.wraps || x % 3 == 0 { raster.light(x, 0); raster.light(x, h) }
        for y in 0...h where !game.mode.wraps || y % 3 == 0 { raster.light(0, y); raster.light(w, y) }
    }

    private func drawSnake(_ game: SnakeGame, previous: [Cell], fraction: Double, now: Double, dead: Bool) {
        let snake = game.snake
        guard !snake.isEmpty else { return }
        func position(_ index: Int) -> (Double, Double) {
            let cell = snake[index]
            let old = index < previous.count ? previous[index] : cell
            let wraps = abs(old.x - cell.x) > 1 || abs(old.y - cell.y) > 1
            let f = wraps ? 1 : fraction
            return (Double(old.x) + Double(cell.x - old.x) * f, Double(old.y) + Double(cell.y - old.y) * f)
        }
        let last = snake.count - 1
        var points: [(Int, Int)] = []
        for index in 0...last {
            let p = (index == 0 || index == last) ? position(index) : (Double(snake[index].x), Double(snake[index].y))
            points.append((center(p.0), center(p.1)))
        }
        // Body: a three-dot tube that follows the path, thinner at the tip of the tail.
        for index in stride(from: last, to: 0, by: -1) {
            let a = points[index], b = points[index - 1]
            guard abs(a.0 - b.0) <= dotsPerCell, abs(a.1 - b.1) <= dotsPerCell, a.0 == b.0 || a.1 == b.1 else { continue }
            let half = index == last ? 0 : 1
            raster.fill(min(a.0, b.0) - half, min(a.1, b.1) - half, max(a.0, b.0) + half, max(a.1, b.1) + half)
            if index == last { raster.fill(b.0 - 1, b.1 - 1, b.0 + 1, b.1 + 1) }
        }
        // Head with an eye that blinks, a mouth that opens next to food, and crossed eyes on a crash.
        let head = points[0]
        let ahead = game.neighbour(of: snake[0], game.direction)
        let hungry = ahead == game.food || (game.bonus != nil && ahead == game.bonus?.cell)
        let blinking = now.truncatingRemainder(dividingBy: 3.2) < 0.14
        let sprite = dead ? Sprites.headDead : hungry ? Sprites.headOpen : blinking ? Sprites.headBlink : Sprites.headClosed
        raster.stamp(sprite, x: head.0 - 2, y: head.1 - 2, facing: game.direction)
    }

    private func drawEffects(now: Double) {
        for particle in model.particles {
            let age = now - particle.born
            guard age >= 0, age < 0.7 else { continue }
            let x = (particle.x + particle.vx * age * 0.6) * Double(dotsPerCell)
            let y = (particle.y + particle.vy * age * 0.6 + 3 * age * age) * Double(dotsPerCell)
            raster.light(1 + Int(x), 1 + Int(y), Float(1 - age / 0.7))
        }
        for popup in model.popups {
            let age = now - popup.born
            guard age >= 0, age < 0.9, age < 0.55 || Int(age * 12) % 2 == 0 else { continue }
            let layout = PixelFont.layout(popup.text)
            let x = 1 + Int(popup.x * Double(dotsPerCell)) - layout.width / 2
            let y = 1 + Int(popup.y * Double(dotsPerCell)) - PixelFont.height - Int(age * 14)
            for (px, py) in layout.pixels { raster.light(x + px, y + py) }
        }
    }
}
