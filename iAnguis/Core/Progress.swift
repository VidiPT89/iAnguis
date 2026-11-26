import Foundation

/// Lifetime statistics kept on the device.
struct PlayerStats: Codable, Equatable {
    var games = 0
    var apples = 0
    var bonus = 0
    var longest = 0
    var bestScore = 0

    mutating func record(_ game: SnakeGame) {
        games += 1
        apples += game.apples
        bonus += game.bonusEaten
        longest = max(longest, game.snake.count)
        bestScore = max(bestScore, game.score)
    }
}

/// Swappable console covers. The first two are free; the rest are earned by playing.
enum Cover: String, CaseIterable, Identifiable {
    case ember, slate, lime, ice, cherry, carbon, aurora, gold
    var id: String { rawValue }

    enum Requirement: Equatable {
        case free, apples(Int), games(Int), score(Int), longest(Int), bonus(Int)
    }

    var requirement: Requirement {
        switch self {
        case .ember, .slate: return .free
        case .lime: return .apples(50)
        case .ice: return .games(15)
        case .cherry: return .score(150)
        case .carbon: return .longest(40)
        case .aurora: return .bonus(15)
        case .gold: return .score(500)
        }
    }

    func isUnlocked(by stats: PlayerStats) -> Bool {
        switch requirement {
        case .free: return true
        case .apples(let n): return stats.apples >= n
        case .games(let n): return stats.games >= n
        case .score(let n): return stats.bestScore >= n
        case .longest(let n): return stats.longest >= n
        case .bonus(let n): return stats.bonus >= n
        }
    }

    /// How far the player is towards this cover, from 0 to 1.
    func progress(for stats: PlayerStats) -> Double {
        switch requirement {
        case .free: return 1
        case .apples(let n): return min(1, Double(stats.apples) / Double(n))
        case .games(let n): return min(1, Double(stats.games) / Double(n))
        case .score(let n): return min(1, Double(stats.bestScore) / Double(n))
        case .longest(let n): return min(1, Double(stats.longest) / Double(n))
        case .bonus(let n): return min(1, Double(stats.bonus) / Double(n))
        }
    }

    static func unlocked(by stats: PlayerStats) -> [Cover] { allCases.filter { $0.isUnlocked(by: stats) } }
}
