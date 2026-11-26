import Foundation
import Observation

/// Moments the interface turns into sound, haptics and celebrations.
enum GameEvent: Equatable {
    case apple(combo: Int), bonus, bonusSpawned, bonusMissed, levelUp, recordBroken, died, won, newRecord, unlocked
}

/// A lit LCD dot flying out of a meal, in cell units.
struct Particle {
    var x, y, vx, vy: Double
    var born: Double
}

/// Floating "+20" style score text, in cell units.
struct Popup {
    var text: String
    var x, y: Double
    var born: Double
}

@MainActor @Observable final class GameModel {
    private(set) var game = SnakeGame()
    private(set) var best: Int
    private(set) var selectedMode = GameMode.classic
    private(set) var stats: PlayerStats
    var showSplash = true
    var showSettings = false
    private(set) var resultVisible = false
    private(set) var isNewRecord = false
    private(set) var newlyUnlocked: [Cover] = []

    // Frame-level state read by the board on every frame; not observed to avoid re-rendering the whole screen.
    @ObservationIgnored private(set) var previousSnake: [Cell] = []
    @ObservationIgnored private(set) var progress = 1.0
    @ObservationIgnored private(set) var demo = SnakeGame()
    @ObservationIgnored private(set) var demoPrevious: [Cell] = []
    @ObservationIgnored private(set) var demoProgress = 1.0
    @ObservationIgnored private(set) var particles: [Particle] = []
    @ObservationIgnored private(set) var popups: [Popup] = []
    @ObservationIgnored private(set) var overAt: Double?
    @ObservationIgnored var onEvent: ((GameEvent) -> Void)?
    /// Called with the mode and score when a round ends, to post it to Game Center.
    @ObservationIgnored var onRoundFinished: ((GameMode, Int) -> Void)?
    /// Current date, replaceable in tests to move between days.
    @ObservationIgnored var currentDate: () -> Date = Date.init
    /// Lets the demo pilot steer a real round; used for screenshots in debug builds.
    @ObservationIgnored var autopilot = false
    @ObservationIgnored private var clock = GameClock()
    @ObservationIgnored private var demoClock = GameClock()
    @ObservationIgnored private var bestAtStart = 0
    @ObservationIgnored private var celebratedRecord = false
    @ObservationIgnored private let defaults: UserDefaults
    static let demoInterval = 0.11
    static let resultDelay = 1.1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let mode = GameMode(rawValue: defaults.string(forKey: "selectedMode") ?? "") ?? .classic
        selectedMode = mode
        if let data = defaults.data(forKey: "stats.v1"), let saved = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            stats = saved
        } else {
            stats = PlayerStats()
        }
        best = 0
        reset(&game, mode: mode, start: false)
        best = best(for: mode)
        previousSnake = game.snake
        restartDemo()
    }

    /// Record key: one per mode, and one per day for the daily challenge.
    private func bestKey(_ mode: GameMode) -> String {
        mode == .daily ? "best.daily.\(DailyChallenge.day(currentDate()))" : "best.\(mode.rawValue)"
    }
    func best(for mode: GameMode) -> Int { defaults.integer(forKey: bestKey(mode)) }
    var dailyStreak: Int {
        let now = currentDate()
        return stats.currentStreak(today: DailyChallenge.day(now), yesterday: DailyChallenge.yesterday(now))
    }

    private func reset(_ target: inout SnakeGame, mode: GameMode, start: Bool) {
        target.reset(mode: mode, start: start, seed: DailyChallenge.seed(currentDate()))
    }

    // MARK: Navigation

    func select(_ mode: GameMode) {
        guard game.phase == .ready else { return }
        selectedMode = mode
        defaults.set(mode.rawValue, forKey: "selectedMode")
        reset(&game, mode: mode, start: false)
        best = best(for: mode)
        restartDemo()
    }

    func cycleMode(_ offset: Int) {
        let all = GameMode.allCases
        let index = all.firstIndex(of: selectedMode) ?? 0
        select(all[(index + offset + all.count) % all.count])
    }

    func start(_ mode: GameMode) {
        selectedMode = mode
        defaults.set(mode.rawValue, forKey: "selectedMode")
        reset(&game, mode: mode, start: true)
        previousSnake = game.snake
        progress = 1
        best = best(for: mode)
        bestAtStart = best
        celebratedRecord = false
        clearRound()
        clock.reset()
    }

    /// Back to the menu. A round abandoned from the pause screen still counts towards statistics and covers.
    func menu() {
        if game.phase == .paused { finishRound() }
        reset(&game, mode: selectedMode, start: false)
        best = best(for: selectedMode)
        previousSnake = game.snake
        progress = 1
        clearRound()
        clock.reset()
        restartDemo()
    }

    func pause() { game.pause(); progress = 1; clock.reset() }
    func resume() { game.resume(); previousSnake = game.snake; progress = 1; clock.reset() }
    func turn(_ direction: Direction) { game.turn(direction) }

    private func clearRound() {
        resultVisible = false
        isNewRecord = false
        newlyUnlocked = []
        overAt = nil
        particles = []
        popups = []
    }

    private func restartDemo() {
        reset(&demo, mode: selectedMode, start: true)
        demoPrevious = demo.snake
        demoProgress = 1
        demoClock.reset()
    }

    // MARK: Frame loop

    func tick(_ now: Double) {
        particles.removeAll { now - $0.born > 0.7 }
        popups.removeAll { now - $0.born > 0.9 }
        switch game.phase {
        case .playing:
            clock.advance(to: now)
            while game.phase == .playing && clock.consume(interval: game.interval) {
                previousSnake = game.snake
                if autopilot, let move = Autopilot.move(for: game) { game.turn(move) }
                handle(game.step(), now: now)
            }
            progress = game.phase == .playing ? clock.progress(interval: game.interval) : 1
        case .over, .won:
            if !resultVisible, let overAt, now - overAt >= Self.resultDelay {
                resultVisible = true
                if isNewRecord { onEvent?(.newRecord) }
                if !newlyUnlocked.isEmpty { onEvent?(.unlocked) }
            }
        case .ready:
            guard !showSplash else { return }
            demoClock.advance(to: now)
            while demoClock.consume(interval: Self.demoInterval) {
                demoPrevious = demo.snake
                if let move = Autopilot.move(for: demo) { demo.turn(move) }
                let result = demo.step()
                if result.died || result.won || demo.snake.count > 70 { restartDemo() }
            }
            demoProgress = demoClock.progress(interval: Self.demoInterval)
        case .paused:
            break
        }
    }

    private func handle(_ result: StepResult, now: Double) {
        let head = game.snake[0]
        if result.ateApple {
            burst(at: head, count: 8 + game.combo * 2, now: now)
            popups.append(Popup(text: "+\(result.applePoints)", x: Double(head.x) + 0.5, y: Double(head.y), born: now))
            onEvent?(.apple(combo: game.combo))
        }
        if result.ateBonus {
            burst(at: head, count: 18, now: now)
            popups.append(Popup(text: "+\(result.bonusPoints)", x: Double(head.x) + 0.5, y: Double(head.y) - 0.6, born: now))
            onEvent?(.bonus)
        }
        if result.bonusSpawned { onEvent?(.bonusSpawned) }
        if result.bonusExpired { onEvent?(.bonusMissed) }
        if result.levelUp { onEvent?(.levelUp) }
        if game.score > bestAtStart, bestAtStart > 0, !celebratedRecord, !result.died {
            celebratedRecord = true
            popups.append(Popup(text: "TOP!", x: Double(head.x) + 0.5, y: Double(head.y) - 1.2, born: now + 0.15))
            onEvent?(.recordBroken)
        }
        if game.score > best {
            best = game.score
            defaults.set(best, forKey: bestKey(game.mode))
        }
        if result.died || result.won {
            overAt = now
            previousSnake = game.snake
            finishRound()
            onEvent?(result.won ? .won : .died)
        }
    }

    private func burst(at cell: Cell, count: Int, now: Double) {
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi + Double.random(in: -0.3...0.3)
            let speed = Double.random(in: 3...7)
            particles.append(Particle(x: Double(cell.x) + 0.5, y: Double(cell.y) + 0.5, vx: cos(angle) * speed, vy: sin(angle) * speed, born: now))
        }
    }

    private func finishRound() {
        let before = stats
        stats.record(game)
        if game.mode == .daily {
            let now = currentDate()
            stats.recordDaily(day: DailyChallenge.day(now), yesterday: DailyChallenge.yesterday(now))
        }
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: "stats.v1") }
        newlyUnlocked = Cover.allCases.filter { !$0.isUnlocked(by: before) && $0.isUnlocked(by: stats) }
        isNewRecord = game.score > bestAtStart && game.score > 0
        onRoundFinished?(game.mode, game.score)
    }

    func resetStats() {
        stats = PlayerStats()
        defaults.removeObject(forKey: "stats.v1")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("best.") { defaults.removeObject(forKey: key) }
        best = 0
    }
}
