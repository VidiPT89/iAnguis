import Foundation

struct Cell: Hashable {
    var x: Int
    var y: Int
}

enum Direction {
    case up, down, left, right
    var delta: Cell {
        switch self {
        case .up: return Cell(x: 0, y: -1)
        case .down: return Cell(x: 0, y: 1)
        case .left: return Cell(x: -1, y: 0)
        case .right: return Cell(x: 1, y: 0)
        }
    }
    func opposes(_ other: Direction) -> Bool {
        delta.x + other.delta.x == 0 && delta.y + other.delta.y == 0
    }
}

/// Small deterministic generator, so the daily challenge is the same on every device.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum GameMode: String, CaseIterable {
    case classic, arcade, maze, zen, daily
    /// Modes where leaving one edge brings the snake back on the opposite one.
    var wraps: Bool { self != .classic }
    var accelerates: Bool { self != .zen }
}

enum GamePhase { case ready, playing, paused, over, won }

/// A short-lived critter worth more the faster it is caught. It never grows the snake.
struct Bonus {
    var cell: Cell
    var stepsLeft: Int
    static let lifetime = 30
    var points: Int { 20 + stepsLeft * 3 }
}

/// What happened during one step, so the interface can react with sound, haptics and effects.
struct StepResult {
    var ateApple = false
    var applePoints = 0
    var ateBonus = false
    var bonusPoints = 0
    var bonusSpawned = false
    var bonusExpired = false
    var levelUp = false
    var died = false
    var won = false
}

struct SnakeGame {
    let columns = 18
    let rows = 22
    static let maxCombo = 5
    static let applesPerLevel = 5
    static let applesPerBonus = 5

    private(set) var snake: [Cell] = []
    private(set) var direction = Direction.right
    private(set) var queued: [Direction] = []
    private(set) var food = Cell(x: 12, y: 11)
    private(set) var bonus: Bonus?
    private(set) var obstacles: Set<Cell> = []
    private(set) var score = 0
    private(set) var apples = 0
    private(set) var bonusEaten = 0
    private(set) var combo = 0
    private(set) var phase = GamePhase.ready
    private(set) var mode = GameMode.classic
    /// Steps taken since the current apple appeared, and the allowance that still counts as a quick catch.
    private(set) var stepsSinceApple = 0
    private(set) var quickAllowance = 11
    /// Seeded generator used by the daily challenge for walls and fruit; nil means system randomness.
    private var seeded: SplitMix64?

    var level: Int { 1 + apples / Self.applesPerLevel }
    var interval: Double { mode.accelerates ? max(0.07, 0.2 - Double(level - 1) * 0.011) : 0.16 }

    init() { reset(mode: .classic, start: false) }

    /// Starts a round. The daily challenge needs the day's seed; other modes ignore it.
    mutating func reset(mode: GameMode, start: Bool = true, seed: UInt64 = 0) {
        self.mode = mode
        let mid = rows / 2
        snake = [Cell(x: 7, y: mid), Cell(x: 6, y: mid), Cell(x: 5, y: mid), Cell(x: 4, y: mid)]
        direction = .right
        queued = []
        switch mode {
        case .maze: obstacles = Self.maze(columns: columns, rows: rows)
        case .daily: obstacles = Self.dailyMaze(seed: seed, columns: columns, rows: rows)
        default: obstacles = []
        }
        seeded = mode == .daily ? SplitMix64(seed: seed ^ 0xA5A5_5A5A) : nil
        food = Cell(x: 12, y: mid)
        bonus = nil
        score = 0
        apples = 0
        bonusEaten = 0
        combo = 0
        stepsSinceApple = 0
        quickAllowance = distance(snake[0], food) + 6
        phase = start ? .playing : .ready
    }

    /// Two bars and four short posts, leaving the starting row open.
    static func maze(columns: Int, rows: Int) -> Set<Cell> {
        var walls = Set<Cell>()
        let top = rows / 4, bottom = rows - 1 - rows / 4
        for x in 3...(columns - 4) {
            walls.insert(Cell(x: x, y: top))
            walls.insert(Cell(x: x, y: bottom))
        }
        let mid = rows / 2
        for x in [3, columns - 4] {
            for y in [mid - 3, mid - 2, mid + 2, mid + 3] { walls.insert(Cell(x: x, y: y)) }
        }
        return walls
    }

    /// Mirrored wall pieces from the day's seed, keeping the starting row open and every free cell reachable.
    static func dailyMaze(seed: UInt64, columns: Int, rows: Int) -> Set<Cell> {
        var random = SplitMix64(seed: seed)
        let mid = rows / 2
        let half = columns / 2
        for _ in 0..<64 {
            var walls = Set<Cell>()
            let pieces = 4 + Int(random.next() % 3)
            for _ in 0..<pieces {
                let horizontal = random.next() % 2 == 0
                let length = 2 + Int(random.next() % 4)
                let x = 1 + Int(random.next() % UInt64(half - 1))
                let y = 1 + Int(random.next() % UInt64(rows - 2))
                for step in 0..<length {
                    let cell = horizontal ? Cell(x: x + step, y: y) : Cell(x: x, y: y + step)
                    guard cell.x < half, cell.y < rows - 1, abs(cell.y - mid) > 1 else { continue }
                    walls.insert(cell)
                    walls.insert(Cell(x: columns - 1 - cell.x, y: cell.y))
                }
            }
            if walls.count >= 12 && allReachable(walls: walls, columns: columns, rows: rows, from: Cell(x: 7, y: mid)) { return walls }
        }
        return maze(columns: columns, rows: rows)
    }

    /// True when every cell that is not a wall can be reached, with wraparound edges.
    static func allReachable(walls: Set<Cell>, columns: Int, rows: Int, from start: Cell) -> Bool {
        var seen: Set<Cell> = [start]
        var stack = [start]
        while let cell = stack.popLast() {
            for d in [Cell(x: 1, y: 0), Cell(x: -1, y: 0), Cell(x: 0, y: 1), Cell(x: 0, y: -1)] {
                let next = Cell(x: (cell.x + d.x + columns) % columns, y: (cell.y + d.y + rows) % rows)
                if !walls.contains(next), seen.insert(next).inserted { stack.append(next) }
            }
        }
        return seen.count == columns * rows - walls.count
    }

    mutating func turn(_ next: Direction) {
        guard phase == .playing, queued.count < 2 else { return }
        let previous = queued.last ?? direction
        guard next != previous, !next.opposes(previous) else { return }
        queued.append(next)
    }

    mutating func pause() { if phase == .playing { phase = .paused; queued = [] } }
    mutating func resume() { if phase == .paused { phase = .playing } }

    /// The neighbouring cell, wrapped in modes without walls, or nil when it leaves the board.
    func neighbour(of cell: Cell, _ direction: Direction) -> Cell? {
        var next = Cell(x: cell.x + direction.delta.x, y: cell.y + direction.delta.y)
        if mode.wraps {
            next.x = (next.x + columns) % columns
            next.y = (next.y + rows) % rows
            return next
        }
        guard next.x >= 0, next.x < columns, next.y >= 0, next.y < rows else { return nil }
        return next
    }

    /// Shortest number of steps between two cells, ignoring the body.
    func distance(_ a: Cell, _ b: Cell) -> Int {
        var dx = abs(a.x - b.x), dy = abs(a.y - b.y)
        if mode.wraps { dx = min(dx, columns - dx); dy = min(dy, rows - dy) }
        return dx + dy
    }

    @discardableResult
    mutating func step() -> StepResult {
        if var generator = seeded {
            let result = step(using: &generator)
            seeded = generator
            return result
        }
        var random = SystemRandomNumberGenerator()
        return step(using: &random)
    }

    @discardableResult
    mutating func step<R: RandomNumberGenerator>(using random: inout R) -> StepResult {
        var result = StepResult()
        guard phase == .playing else { return result }
        if !queued.isEmpty { direction = queued.removeFirst() }
        stepsSinceApple += 1
        guard let head = neighbour(of: snake[0], direction) else {
            phase = .over
            result.died = true
            return result
        }
        let eating = head == food
        let body = eating ? snake[...] : snake.dropLast()
        guard !obstacles.contains(head), !body.contains(head) else {
            phase = .over
            result.died = true
            return result
        }
        snake.insert(head, at: 0)

        if let current = bonus, current.cell == head {
            result.ateBonus = true
            result.bonusPoints = current.points
            score += current.points
            bonusEaten += 1
            bonus = nil
        }

        if eating {
            let previousLevel = level
            combo = stepsSinceApple <= quickAllowance ? min(combo + 1, Self.maxCombo) : 1
            let points = 10 * combo
            score += points
            apples += 1
            result.ateApple = true
            result.applePoints = points
            result.levelUp = mode.accelerates && level > previousLevel
            if !placeFood(using: &random) {
                phase = .won
                result.won = true
                return result
            }
            if apples.isMultiple(of: Self.applesPerBonus), bonus == nil {
                result.bonusSpawned = placeBonus(using: &random)
            }
        } else {
            snake.removeLast()
        }

        if !result.ateBonus, !result.bonusSpawned, var current = bonus {
            current.stepsLeft -= 1
            if current.stepsLeft <= 0 { bonus = nil; result.bonusExpired = true } else { bonus = current }
        }
        return result
    }

    private func freeCells() -> [Cell] {
        let occupied = Set(snake).union(obstacles)
        return (0..<rows).flatMap { y in (0..<columns).map { Cell(x: $0, y: y) } }.filter { !occupied.contains($0) }
    }

    /// Places the next apple. Returns false when the board is full.
    private mutating func placeFood<R: RandomNumberGenerator>(using random: inout R) -> Bool {
        let free = freeCells()
        let candidates = free.filter { $0 != bonus?.cell }
        if let next = candidates.randomElement(using: &random) {
            food = next
        } else if let critter = bonus, free.contains(critter.cell) {
            bonus = nil
            food = critter.cell
        } else {
            return false
        }
        stepsSinceApple = 0
        quickAllowance = distance(snake[0], food) + 6
        return true
    }

    private mutating func placeBonus<R: RandomNumberGenerator>(using random: inout R) -> Bool {
        let candidates = freeCells().filter { $0 != food && distance($0, snake[0]) > 2 }
        guard let cell = candidates.randomElement(using: &random) else { return false }
        bonus = Bonus(cell: cell, stepsLeft: Bonus.lifetime)
        return true
    }
}
