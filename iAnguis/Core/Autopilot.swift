import Foundation

/// Plays the attract-mode demo on the menu: shortest path to food, otherwise the roomiest safe move.
enum Autopilot {
    static func move(for game: SnakeGame) -> Direction? {
        guard let head = game.snake.first else { return nil }
        let blocked = Set(game.snake.dropLast()).union(game.obstacles)
        let directions: [Direction] = [.up, .right, .down, .left]

        // Breadth-first search towards the apple.
        var cameFrom: [Cell: (Cell, Direction)] = [:]
        var queue = [head]
        var visited: Set<Cell> = [head]
        var index = 0
        while index < queue.count {
            let cell = queue[index]
            index += 1
            if cell == game.food { break }
            for direction in directions {
                guard let next = game.neighbour(of: cell, direction), !blocked.contains(next), !visited.contains(next) else { continue }
                visited.insert(next)
                cameFrom[next] = (cell, direction)
                queue.append(next)
            }
        }
        if cameFrom[game.food] != nil {
            var cell = game.food
            var first = cameFrom[cell]!.1
            while let (previous, direction) = cameFrom[cell] {
                first = direction
                if previous == head { break }
                cell = previous
            }
            if !first.opposes(game.direction) { return first }
        }

        // No path: pick the move that keeps the most room.
        var best: (Direction, Int)?
        for direction in directions where !direction.opposes(game.direction) {
            guard let next = game.neighbour(of: head, direction), !blocked.contains(next) else { continue }
            let room = reachable(from: next, blocked: blocked.union([head]), game: game)
            if best == nil || room > best!.1 { best = (direction, room) }
        }
        return best?.0
    }

    private static func reachable(from start: Cell, blocked: Set<Cell>, game: SnakeGame) -> Int {
        var seen: Set<Cell> = [start]
        var stack = [start]
        while let cell = stack.popLast(), seen.count < 200 {
            for direction in [Direction.up, .right, .down, .left] {
                guard let next = game.neighbour(of: cell, direction), !blocked.contains(next), seen.insert(next).inserted else { continue }
                stack.append(next)
            }
        }
        return seen.count
    }
}
