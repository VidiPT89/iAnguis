import AVFoundation
import QuartzCore
import UIKit

/// Piezo-style square-wave beeps, synthesised once at launch. No audio files are bundled.
@MainActor final class SoundBoard {
    static let shared = SoundBoard()

    enum Sound: Hashable {
        case eat(Int), bonus, spawn, missed, level, top, die, win, record, unlock, click, start, intro
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var ready = false

    private init() {}

    private func prepare() {
        guard !ready else { return }
        ready = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.55
        let C6 = 1046.5, E6 = 1318.5, G6 = 1568.0, C7 = 2093.0, G5 = 784.0, E5 = 659.3, D6 = 1174.7, A5 = 880.0
        for combo in 1...SnakeGame.maxCombo {
            let base = 880 * pow(1.122, Double(combo - 1))
            buffers[.eat(combo)] = render([(base, 0.035), (base * 1.5, 0.045)])
        }
        buffers[.bonus] = render([(C6, 0.045), (E6, 0.045), (G6, 0.045), (C7, 0.09)])
        buffers[.spawn] = render([(G6, 0.03), (0, 0.04), (G6, 0.03)])
        buffers[.missed] = render([(392, 0.06), (311, 0.12)], volume: 0.7)
        buffers[.top] = render([(G6, 0.05), (C7, 0.05), (G6, 0.05), (C7, 0.12)])
        buffers[.level] = render([(G5, 0.06), (C6, 0.06), (E6, 0.06), (G6, 0.12)])
        buffers[.die] = render([(G5, 0.09), (622, 0.09), (494, 0.09), (392, 0.1), (330, 0.28)])
        buffers[.win] = render([(C6, 0.08), (E6, 0.08), (G6, 0.08), (C7, 0.08), (G6, 0.08), (C7, 0.3)])
        buffers[.record] = render([(C6, 0.07), (C6, 0.07), (0, 0.03), (G6, 0.08), (E6, 0.08), (C7, 0.26)])
        buffers[.unlock] = render([(E6, 0.06), (G6, 0.06), (E6 * 2, 0.16)])
        buffers[.click] = render([(C7, 0.012)], volume: 0.5)
        buffers[.start] = render([(A5, 0.05), (E6, 0.08)])
        buffers[.intro] = render([(E5, 0.08), (G5, 0.08), (C6, 0.08), (D6, 0.08), (G6, 0.2)])
    }

    private func render(_ notes: [(Double, Double)], volume: Float = 1) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let total = notes.reduce(0) { $0 + Int($1.1 * rate) }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total))!
        buffer.frameLength = AVAudioFrameCount(total)
        let samples = buffer.floatChannelData![0]
        var offset = 0
        for (frequency, duration) in notes {
            let count = Int(duration * rate)
            let ramp = min(Int(0.003 * rate), count / 2)
            for i in 0..<count {
                var value: Float = 0
                if frequency > 0 {
                    let phase = (Double(i) * frequency / rate).truncatingRemainder(dividingBy: 1)
                    value = phase < 0.5 ? 0.16 : -0.16
                    let envelope = min(1, Float(min(i, count - 1 - i)) / Float(max(1, ramp)))
                    value *= envelope * volume
                }
                samples[offset + i] = value
            }
            offset += count
        }
        return buffer
    }

    func play(_ sound: Sound) {
        guard UserDefaults.standard.bool(forKey: "sound") else { return }
        prepare()
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning, let buffer = buffers[sound] else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }
}

@MainActor enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    private static var enabled: Bool { UserDefaults.standard.bool(forKey: "haptics") }
    static func tap() { if enabled { light.impactOccurred(intensity: 0.6) } }
    static func eat(_ combo: Int) { if enabled { rigid.impactOccurred(intensity: min(1, 0.5 + Double(combo) * 0.1)) } }
    static func crash() { if enabled { heavy.impactOccurred() } }
    static func success() { if enabled { notification.notificationOccurred(.success) } }
}

/// Plays the right sound and haptic for each game moment.
@MainActor enum Feedback {
    static func handle(_ event: GameEvent) {
        switch event {
        case .apple(let combo): SoundBoard.shared.play(.eat(combo)); Haptics.eat(combo)
        case .bonus: SoundBoard.shared.play(.bonus); Haptics.success()
        case .bonusSpawned: SoundBoard.shared.play(.spawn)
        case .bonusMissed: SoundBoard.shared.play(.missed)
        case .recordBroken: SoundBoard.shared.play(.top); Haptics.success()
        case .levelUp: SoundBoard.shared.play(.level)
        case .died: SoundBoard.shared.play(.die); Haptics.crash()
        case .won: SoundBoard.shared.play(.win); Haptics.success()
        case .newRecord: SoundBoard.shared.play(.record); Haptics.success()
        case .unlocked: SoundBoard.shared.play(.unlock)
        }
    }
}

/// Drives the game from the display refresh, up to 120 Hz on ProMotion screens.
@MainActor final class FrameDriver: NSObject {
    private var link: CADisplayLink?
    var onFrame: ((Double) -> Void)?

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(frame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func frame() { onFrame?(ProcessInfo.processInfo.systemUptime) }
}
