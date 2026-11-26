import Foundation

/// Accumulates monotonic time while keeping long interruptions bounded.
struct GameClock {
    private var previous: TimeInterval?
    private(set) var elapsed: TimeInterval = 0

    mutating func reset() {
        previous = nil
        elapsed = 0
    }

    mutating func advance(to time: TimeInterval) {
        defer { previous = time }
        guard let previous else { return }
        elapsed += min(max(0, time - previous), 0.25)
    }

    mutating func consume(interval: TimeInterval) -> Bool {
        guard elapsed >= interval else { return false }
        elapsed -= interval
        return true
    }

    func progress(interval: TimeInterval) -> Double {
        min(1, elapsed / interval)
    }
}
