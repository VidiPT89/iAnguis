import GameKit
import UIKit

/// Game Center sign-in, score posting and the leaderboards screen.
/// One leaderboard per mode, plus a daily leaderboard that restarts every day for the daily challenge.
@MainActor @Observable final class GameCenter {
    static let shared = GameCenter()
    private(set) var enabled = false
    @ObservationIgnored private let dismisser = Dismisser()
    @ObservationIgnored private var started = false

    private init() {}

    static func leaderboardID(_ mode: GameMode) -> String { "dev.ividi.iAnguis.\(mode.rawValue)" }

    func authenticate() {
        guard !started else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, _ in
            Task { @MainActor in
                if let controller {
                    Self.present(controller)
                } else {
                    self?.enabled = GKLocalPlayer.local.isAuthenticated
                }
            }
        }
    }

    func submit(score: Int, mode: GameMode) {
        guard enabled, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardID(mode)]) { _ in }
    }

    func showLeaderboards() {
        guard enabled else { return }
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = dismisser
        Self.present(controller)
    }

    private static func present(_ controller: UIViewController) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        top.present(controller, animated: true)
    }

    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            controller.dismiss(animated: true)
        }
    }
}
