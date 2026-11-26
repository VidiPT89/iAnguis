import Foundation

/// Lifetime statistics kept on the device.
struct PlayerStats: Codable, Equatable {
    var games = 0
    var apples = 0
    var bonus = 0
    var longest = 0
    var bestScore = 0
    /// Consecutive days with a daily challenge played, and the last such day ("yyyy-MM-dd", UTC).
    var dailyStreak = 0
    var lastDaily = ""

    init() {}

    /// Tolerates saves written before a field existed, so an update never wipes progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        games = try c.decodeIfPresent(Int.self, forKey: .games) ?? 0
        apples = try c.decodeIfPresent(Int.self, forKey: .apples) ?? 0
        bonus = try c.decodeIfPresent(Int.self, forKey: .bonus) ?? 0
        longest = try c.decodeIfPresent(Int.self, forKey: .longest) ?? 0
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        dailyStreak = try c.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 0
        lastDaily = try c.decodeIfPresent(String.self, forKey: .lastDaily) ?? ""
    }

    /// Counts a daily challenge played on `day`, given the previous calendar day.
    mutating func recordDaily(day: String, yesterday: String) {
        guard lastDaily != day else { return }
        dailyStreak = lastDaily == yesterday ? dailyStreak + 1 : 1
        lastDaily = day
    }

    /// The streak still shown today: it lapses once a whole day is skipped.
    func currentStreak(today: String, yesterday: String) -> Int {
        lastDaily == today || lastDaily == yesterday ? dailyStreak : 0
    }

    mutating func record(_ game: SnakeGame) {
        games += 1
        apples += game.apples
        bonus += game.bonusEaten
        longest = max(longest, game.snake.count)
        bestScore = max(bestScore, game.score)
    }
}

/// Swappable console covers. The first two are free; the rest are earned by playing.
/// The calendar day of the daily challenge, in UTC so it is the same everywhere.
enum DailyChallenge {
    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    static func day(_ date: Date) -> String { formatter().string(from: date) }
    static func yesterday(_ date: Date) -> String { day(date.addingTimeInterval(-86_400)) }
    static func seed(_ date: Date) -> UInt64 {
        let digits = UInt64(day(date).replacingOccurrences(of: "-", with: "")) ?? 0
        return digits &* 0x2545_F491_4F6C_DD1D
    }
}

enum Cover: String, CaseIterable, Identifiable {
    case ember, slate, lime, ice, cherry, carbon, aurora, gold
    var id: String { rawValue }

    enum Requirement {
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
}
