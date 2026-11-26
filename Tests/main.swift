import Foundation

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
    checks += 1
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

var game = SnakeGame()
let mid = game.rows / 2
check(game.phase == .ready, "Starts ready")

// Turning and input buffering
game.reset(mode: .classic)
game.turn(.left)
game.step()
check(game.snake[0] == Cell(x: 8, y: mid), "Cannot reverse")
game.turn(.up)
game.turn(.left)
game.turn(.down)
game.step()
check(game.direction == .up, "First buffered turn")
game.step()
check(game.direction == .left, "Second buffered turn")
game.pause()
let paused = game.snake
game.step()
check(game.snake == paused, "Pause freezes game")
game.resume()
check(game.phase == .playing, "Resumes")

// Eating, combo and walls
game.reset(mode: .classic)
var result = StepResult()
for _ in 0..<5 { result = game.step() }
check(result.ateApple && result.applePoints == 10, "Apple scores 10")
check(game.score == 10 && game.snake.count == 5 && game.combo == 1, "Food grows snake and starts combo")
check(!game.snake.contains(game.food), "Food spawns in free cell")
for _ in 0..<30 where game.phase == .playing { game.step() }
check(game.phase == .over, "Classic wall collision")

// Combo grows on quick catches and resets on slow ones
var random = SeededRandom(state: 7)
game.reset(mode: .zen)
var points: [Int] = []
while game.apples < 3 && game.phase == .playing {
    if let move = Autopilot.move(for: game) { game.turn(move) }
    let step = game.step(using: &random)
    if step.ateApple { points.append(step.applePoints) }
}
check(points == [10, 20, 30], "Quick catches build the combo: \(points)")
game.reset(mode: .zen)
for _ in 0..<5 { game.step() }
for _ in 0..<40 { game.turn(.up); game.step(); game.turn(.right); game.step(); game.turn(.down); game.step(); game.turn(.right); game.step() }
check(game.phase == .playing, "Zen run survives")

// Wraparound and steady pace
game.reset(mode: .arcade)
game.turn(.up)
for _ in 0..<(mid + 1) { game.step() }
check(game.snake[0].y == game.rows - 1 && game.phase == .playing, "Arcade wraps")
game.reset(mode: .zen)
check(game.interval == 0.16, "Zen speed")
game.turn(.up); game.step()
game.turn(.left); game.step()
game.turn(.down); game.step()
check(game.phase == .playing, "Entering vacated tail allowed")
game.reset(mode: .classic)
for _ in 0..<5 { game.step() }
game.turn(.up); game.step()
game.turn(.left); game.step()
game.turn(.down); game.step()
check(game.phase == .over, "Body collision ends game")

// Maze
game.reset(mode: .maze)
check(!game.obstacles.isEmpty && !game.obstacles.contains(game.food), "Maze has walls and a reachable apple")
check(game.snake.allSatisfy { !game.obstacles.contains($0) }, "Maze start is clear")
check((0..<game.columns).allSatisfy { !game.obstacles.contains(Cell(x: $0, y: mid)) }, "Starting row is open")
game.turn(.up)
for _ in 0..<12 where game.phase == .playing { game.step() }
check(game.phase == .over, "Maze wall ends the round")

// Level and speed
game.reset(mode: .arcade)
check(game.level == 1 && game.interval == 0.2, "Starts at level 1")

// Clock
var clock = GameClock()
clock.advance(to: 10)
check(clock.elapsed == 0, "First frame does not advance")
clock.advance(to: 10.1)
check(!clock.consume(interval: 0.2), "Fractional frame retained")
clock.advance(to: 10.21)
check(clock.consume(interval: 0.2), "Accumulated time produces tick")
check(clock.elapsed < 0.011, "Remainder retained")
clock.reset()
clock.advance(to: 100)
clock.advance(to: 500)
check(clock.elapsed == 0.25, "Long stalls are bounded")
clock.reset()
clock.advance(to: 10)
clock.advance(to: 9)
check(clock.elapsed == 0, "Backward timestamps cannot subtract time")

func ticks(at fps: Int) -> Int {
    var clock = GameClock()
    var count = 0
    for frame in 0...fps * 10 {
        clock.advance(to: Double(frame) / Double(fps))
        while clock.consume(interval: 0.16) { count += 1 }
    }
    return count
}
check(Set([20, 30, 60, 120, 144].map(ticks)).count == 1, "Same rules across frame rates")

game.reset(mode: .classic)
game.turn(.up)
game.turn(.right)
check(game.queued.count == 2, "Two turns buffered")
game.pause()
check(game.queued.isEmpty, "Pause drops buffered input")
game.turn(.down)
check(game.queued.isEmpty, "Paused input ignored")
game.resume()
game.step()
check(game.direction == .right, "No stale turn on resume")

// Bonus critters
random = SeededRandom(state: 99)
game.reset(mode: .zen)
var sawBonus = false
while game.apples < 10 && game.phase == .playing {
    if let move = Autopilot.move(for: game) { game.turn(move) }
    let step = game.step(using: &random)
    if step.bonusSpawned {
        sawBonus = true
        check(game.bonus!.stepsLeft == Bonus.lifetime && game.bonus!.cell != game.food, "Bonus spawns away from the apple")
        check(!game.snake.contains(game.bonus!.cell), "Bonus spawns in a free cell")
    }
    if step.ateBonus { check(step.bonusPoints >= 20, "Bonus pays at least 20") }
}
check(sawBonus && game.apples == 10, "Bonus appears every five apples")

// A bonus that is never caught runs out after exactly its lifetime
var expiryChecked = false
for seed in UInt64(1)...40 where !expiryChecked {
    var rng = SeededRandom(state: seed)
    game.reset(mode: .zen)
    var stepsSinceSpawn = -1
    while game.phase == .playing && game.apples < 30 {
        if let move = Autopilot.move(for: game) { game.turn(move) }
        let step = game.step(using: &rng)
        if step.bonusSpawned { stepsSinceSpawn = 0; continue }
        if stepsSinceSpawn >= 0 { stepsSinceSpawn += 1 }
        if step.ateBonus { stepsSinceSpawn = -1 }
        if step.bonusExpired {
            check(stepsSinceSpawn == Bonus.lifetime, "Uncaught bonus expires after its lifetime: \(stepsSinceSpawn)")
            expiryChecked = true
            break
        }
    }
}
check(expiryChecked, "Found an uncaught bonus to check expiry")

// Demo autopilot survives a while on every mode
for mode in GameMode.allCases {
    var demo = SnakeGame()
    var rng = SeededRandom(state: 3)
    demo.reset(mode: mode)
    var steps = 0
    while demo.phase == .playing && steps < 400 {
        if let move = Autopilot.move(for: demo) { demo.turn(move) }
        demo.step(using: &rng)
        steps += 1
    }
    check(demo.apples >= 8, "Autopilot eats on \(mode): \(demo.apples)")
}

// Follow a Hamiltonian cycle until every cell is filled, exercising growth
// and food placement without depending on a lucky sequence of random fruit.
random = SeededRandom(state: 12345)
game.reset(mode: .classic)
game.turn(.up)  // start on an even row so the cycle runs rightwards
game.step(using: &random)
var moves = 0
let lastX = game.columns - 1, lastY = game.rows - 1
while game.phase == .playing && moves < 300_000 {
    let head = game.snake[0]
    let next: Direction
    if head.x == 0 { next = head.y == 0 ? .right : .up }
    else if head.y.isMultiple(of: 2) { next = head.x == lastX ? .down : .right }
    else if head.x > 1 { next = .left }
    else { next = head.y == lastY ? .left : .down }
    game.turn(next)
    let step = game.step(using: &random)
    if step.ateApple && game.phase == .playing {
        check(!game.snake.contains(game.food), "Food stays outside growing body")
    }
    moves += 1
}
let cells = game.columns * game.rows
check(game.phase == .won, "Full board wins without a spawn loop")
check(game.snake.count == cells && Set(game.snake).count == cells, "Victory occupies each cell once")
check(game.apples == cells - 4 && game.score >= game.apples * 10, "Full-board score")
check(game.interval == 0.07, "Speed floor respected")
let wonSnake = game.snake
game.step()
check(game.snake == wonSnake, "Win is terminal")

// Daily challenge: same walls and fruit for the same seed, open start row, reachable board
let seedA = DailyChallenge.seed(Date(timeIntervalSince1970: 1_790_000_000))
let seedB = DailyChallenge.seed(Date(timeIntervalSince1970: 1_790_000_000 + 86_400))
var dayOne = SnakeGame(), dayOneAgain = SnakeGame(), dayTwo = SnakeGame()
dayOne.reset(mode: .daily, seed: seedA)
dayOneAgain.reset(mode: .daily, seed: seedA)
dayTwo.reset(mode: .daily, seed: seedB)
check(dayOne.obstacles == dayOneAgain.obstacles && dayOne.obstacles != dayTwo.obstacles, "Daily walls depend only on the day")
check(dayOne.obstacles.count >= 12, "Daily maze has walls")
check((0..<dayOne.columns).allSatisfy { !dayOne.obstacles.contains(Cell(x: $0, y: mid)) }, "Daily start row is open")
for day in 0..<60 {
    let walls = SnakeGame.dailyMaze(seed: DailyChallenge.seed(Date(timeIntervalSince1970: 1_790_000_000 + Double(day) * 86_400)), columns: 18, rows: 22)
    check(SnakeGame.allReachable(walls: walls, columns: 18, rows: 22, from: Cell(x: 7, y: 11)), "Daily maze \(day) fully reachable")
    check(walls.allSatisfy { $0.x != 7 || $0.y != 11 } && !walls.contains(Cell(x: 12, y: 11)), "Daily maze \(day) keeps start and first apple free")
}
var foods: [[Cell]] = []
for _ in 0..<2 {
    var run = SnakeGame()
    run.reset(mode: .daily, seed: seedA)
    var eaten: [Cell] = []
    while run.apples < 6 && run.phase == .playing {
        if let move = Autopilot.move(for: run) { run.turn(move) }
        if run.step().ateApple { eaten.append(run.food) }
    }
    foods.append(eaten)
}
check(foods[0] == foods[1] && foods[0].count == 6, "Same moves give the same fruit on the same day")
check(DailyChallenge.day(Date(timeIntervalSince1970: 0)) == "1970-01-01", "Daily key is the UTC day")

var streak = PlayerStats()
streak.recordDaily(day: "2026-11-25", yesterday: "2026-11-24")
streak.recordDaily(day: "2026-11-25", yesterday: "2026-11-24")
streak.recordDaily(day: "2026-11-26", yesterday: "2026-11-25")
check(streak.dailyStreak == 2, "Streak grows once per consecutive day")
check(streak.currentStreak(today: "2026-11-27", yesterday: "2026-11-26") == 2, "Streak alive the next day")
check(streak.currentStreak(today: "2026-11-28", yesterday: "2026-11-27") == 0, "Streak lapses after a skipped day")
streak.recordDaily(day: "2026-11-28", yesterday: "2026-11-27")
check(streak.dailyStreak == 1, "Streak restarts after a gap")
let oldSave = #"{"games":3,"apples":9,"bonus":1,"longest":12,"bestScore":90}"#.data(using: .utf8)!
let migrated = try! JSONDecoder().decode(PlayerStats.self, from: oldSave)
check(migrated.games == 3 && migrated.dailyStreak == 0 && migrated.lastDaily == "", "Saves without daily fields still load")

// Progress and covers
var stats = PlayerStats()
check(Cover.allCases.filter { $0.isUnlocked(by: stats) } == [.ember, .slate], "Two free covers")
stats.apples = 50
check(Cover.lime.isUnlocked(by: stats) && !Cover.gold.isUnlocked(by: stats), "Apples unlock lime")
stats.bestScore = 250
check(abs(Cover.gold.progress(for: stats) - 0.5) < 0.001, "Cover progress")
stats.record(game)
check(stats.games == 1 && stats.longest == cells && Cover.gold.isUnlocked(by: stats), "Recording a round updates stats")

MainActor.assumeIsolated {
    let suite = "iAnguis.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(70, forKey: "best.arcade")
    let model = GameModel(defaults: defaults)
    model.showSplash = false
    model.select(.arcade)
    check(model.best == 70 && model.game.mode == .arcade, "Mode selection updates preview and record")
    let restored = GameModel(defaults: defaults)
    check(restored.selectedMode == .arcade, "Selected mode restored")
    model.cycleMode(1)
    check(model.selectedMode == .maze && model.demo.mode == .maze, "Cycling modes restarts demo in that mode")
    model.cycleMode(-2)
    check(model.selectedMode == .classic, "Cycling backwards wraps")
    model.tick(0)
    for frame in 1...120 { model.tick(Double(frame) / 60) }
    check(model.demo.snake != SnakeGame().snake || model.demo.apples > 0, "Demo plays on the menu")

    var events: [GameEvent] = []
    model.onEvent = { events.append($0) }
    model.start(.classic)
    model.tick(0)
    for frame in 1...70 { model.tick(Double(frame) / 60) }
    check(model.game.score == 10 && defaults.integer(forKey: "best.classic") == 10, "Score is stored after eating")
    check(events.contains(.apple(combo: 1)) && !model.particles.isEmpty && !model.popups.isEmpty, "Eating fires event and effects")
    model.pause()
    let pausedSnake = model.game.snake
    model.tick(500)
    check(model.game.snake == pausedSnake, "Coordinator pause ignores elapsed time")
    model.resume()
    model.tick(1000)
    check(model.game.snake == pausedSnake, "Resume does not catch up background time")
    check(model.previousSnake == pausedSnake, "Resume interpolation starts at current position")
    var now = 1000.0
    while model.game.phase == .playing { now += 1.0 / 60; model.tick(now) }
    check(model.game.phase == .over && events.contains(.died) && !model.resultVisible, "Death waits for the blink animation")
    model.tick(now + GameModel.resultDelay + 0.01)
    check(model.resultVisible && model.isNewRecord && events.contains(.newRecord), "Result shows after delay with record")
    check(model.stats.games == 1 && model.stats.apples == 1, "Stats recorded once")
    check(GameModel(defaults: defaults).stats == model.stats, "Stats persist")
    model.select(.zen)
    check(model.selectedMode == .classic, "Mode cannot change on the result screen")
    model.menu()
    check(model.game.phase == .ready && model.game.score == 0 && !model.resultVisible, "End round returns to fresh menu")
    check(model.best == 10, "Returning to menu retains the played mode record")
    model.select(.arcade)
    check(model.best == 70, "Other mode records are preserved")
    // Beating a record mid-round is celebrated once; quitting from pause still counts the round.
    events = []
    model.start(.classic)
    model.tick(2000)
    var clockTime = 2000.0
    for _ in 0..<70 { clockTime += 1.0 / 60; model.tick(clockTime) }
    check(model.game.score == 10 && !events.contains(.recordBroken), "Equalling the record is not a new record")
    while model.game.apples < 2 && model.game.phase == .playing {
        if let move = Autopilot.move(for: model.game) { model.turn(move) }
        clockTime += 1.0 / 60
        model.tick(clockTime)
    }
    check(events.filter { $0 == .recordBroken }.count == 1, "Record broken once")
    check(model.popups.contains { $0.text == "TOP!" }, "Record popup shown")
    let gamesBefore = model.stats.games
    model.pause()
    model.menu()
    check(model.stats.games == gamesBefore + 1 && model.stats.apples >= 3, "Quitting from pause records the round")
    // Daily challenge records are per day and feed the streak and Game Center hook.
    var day = Date(timeIntervalSince1970: 1_790_000_000)
    model.currentDate = { day }
    var posted: [(GameMode, Int)] = []
    model.onRoundFinished = { posted.append(($0, $1)) }
    model.menu()
    model.select(.daily)
    check(model.game.obstacles == SnakeGame.dailyMaze(seed: DailyChallenge.seed(day), columns: 18, rows: 22), "Daily menu shows today's maze")
    model.start(.daily)
    var t2 = 5000.0
    model.tick(t2)
    while model.game.phase == .playing && model.game.apples < 1 {
        if let move = Autopilot.move(for: model.game) { model.turn(move) }
        t2 += 1.0 / 60; model.tick(t2)
    }
    model.pause(); model.menu()
    check(model.best(for: .daily) >= 10 && model.dailyStreak == 1, "Daily record and streak saved")
    check(posted.last?.0 == .daily && posted.last!.1 >= 10, "Round posted for Game Center")
    day = day.addingTimeInterval(86_400)
    check(model.best(for: .daily) == 0 && model.dailyStreak == 1, "New day: fresh daily record, streak still alive")
    model.resetStats()
    check(model.stats == PlayerStats() && model.best(for: .arcade) == 0, "Reset clears stats and records")
    day = day.addingTimeInterval(-86_400)
    check(model.best(for: .daily) == 0, "Reset clears daily records")
    defaults.set("invalid", forKey: "selectedMode")
    check(GameModel(defaults: defaults).selectedMode == .classic, "Invalid stored mode has safe default")
}
print("Passed \(checks) checks, including a complete \(moves)-move winning game")
