import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()
    @State private var driver = FrameDriver()
    @AppStorage("cover") private var coverID = Cover.ember.rawValue
    @AppStorage("lcd") private var lcdID = LCDStyle.green.rawValue
    @AppStorage("motion") private var motion = "smooth"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private var cover: Cover {
        let chosen = Cover(rawValue: coverID) ?? .ember
        return chosen.isUnlocked(by: model.stats) ? chosen : .ember
    }
    private var palette: LCDPalette { (LCDStyle(rawValue: lcdID) ?? .green).palette }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ConsoleView(model: model, style: cover.style, palette: palette, available: geo.size,
                            smooth: motion == "smooth", reduceMotion: reduceMotion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(model.showSplash)
                if model.showSplash {
                    SplashView(style: cover.style, palette: palette, reduceMotion: reduceMotion) {
                        guard model.showSplash else { return }
                        withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeInOut(duration: 0.55)) { model.showSplash = false }
                        GameCenter.shared.authenticate()
                    }
                    .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 1.08))))
                    .zIndex(2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background { Backdrop(style: cover.style, dark: scheme == .dark, reduceMotion: reduceMotion) }
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model)
                .tint(cover.style.tint)
        }
        .onAppear {
            model.onEvent = { Feedback.handle($0) }
            model.onRoundFinished = { GameCenter.shared.submit(score: $1, mode: $0) }
            driver.onFrame = { [model] now in model.tick(now) }
            driver.start()
            #if DEBUG
            // Debug-only launch arguments that bring the game to a given state for simulator screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-settings") { model.showSplash = false; model.showSettings = true }
            if let index = arguments.firstIndex(of: "-autoplay"), index + 1 < arguments.count {
                let mode = arguments[index + 1]
                model.showSplash = false
                model.autopilot = !arguments.contains("-crash")
                model.start(GameMode(rawValue: mode) ?? .classic)
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { driver.start() } else { model.pause(); driver.stop() }
        }
    }
}

// MARK: Background

private struct Backdrop: View {
    let style: CoverStyle
    let dark: Bool
    let reduceMotion: Bool
    @State private var breathe = false

    var body: some View {
        ZStack {
            (dark ? Color(hex: 0x0C0C10) : Color(hex: 0xF3EFE8)).ignoresSafeArea()
            Canvas { context, size in
                var dots = Path()
                let step: CGFloat = 16
                for y in stride(from: 0, through: size.height, by: step) {
                    for x in stride(from: 0, through: size.width, by: step) { dots.addRect(CGRect(x: x, y: y, width: 2, height: 2)) }
                }
                context.fill(dots, with: .color((dark ? Color.white : Color.black).opacity(0.045)))
            }
            .ignoresSafeArea()
            Circle()
                .fill(RadialGradient(colors: [style.top.opacity(dark ? 0.55 : 0.4), .clear], center: .center, startRadius: 0, endRadius: 260))
                .frame(width: 560, height: 560)
                .scaleEffect(breathe ? 1.08 : 0.9)
                .offset(y: -60)
                .animation(reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)
                .onAppear { breathe = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Console

private struct ConsoleView: View {
    let model: GameModel
    let style: CoverStyle
    let palette: LCDPalette
    let available: CGSize
    let smooth: Bool
    let reduceMotion: Bool
    @Environment(\.loc) private var t

    private var largeScreen: Bool { available.width > 700 && available.height > 700 }
    private var padSize: CGFloat { min(largeScreen ? 220 : 178, max(128, available.width * 0.4, (available.height - 600) * 0.6 + 128)) }
    /// Wide screens (an iPad on its side) put the keys beside the LCD instead of below it.
    private var landscape: Bool { available.width > available.height * 1.15 && available.width > 700 }
    /// Width of the dot-matrix board, limited by both the width and the height of the screen.
    private var boardWidth: CGFloat {
        if landscape {
            let fixed: CGFloat = 26 + 46 + 18 + 40 + 30 + 36 + 34
            let byHeight = (available.height - 16 - fixed) * BoardView.aspect
            let byWidth = available.width - 28 - 76 - padSize - 64
            return max(180, min(byWidth, byHeight))
        }
        let fixed: CGFloat = 26 + 46 + 18 + 40 + 44 + 30 + 36 + 34 + padSize
        let byWidth = min(available.width - 28, largeScreen ? 660 : 500) - 76
        let byHeight = (available.height - 16 - fixed) * BoardView.aspect
        return max(180, min(byWidth, byHeight))
    }
    private var phase: GamePhase { model.game.phase }

    var body: some View {
        Group {
            if landscape {
                HStack(spacing: 28) {
                    VStack(spacing: 12) {
                        topDetails
                        screen
                    }
                    .frame(width: boardWidth + 44)
                    VStack(spacing: 28) {
                        softKeys
                        NavPad(size: padSize, style: style, centerIcon: centerIcon, centerLabel: centerLabel, onDirection: press, onCenter: ok)
                    }
                    .frame(width: max(padSize, 160) + 24)
                }
                .padding(16)
                .padding(.horizontal, 6)
            } else {
                VStack(spacing: 12) {
                    topDetails
                    screen
                    softKeys
                    NavPad(size: padSize, style: style, centerIcon: centerIcon, centerLabel: centerLabel, onDirection: press, onCenter: ok)
                        .padding(.bottom, 4)
                }
                .padding(16)
                .padding(.top, 4)
                .frame(width: boardWidth + 76)
            }
        }
        .background(shell)
    }

    private var screen: some View {
        LCDScreen(model: model, palette: palette, boardWidth: boardWidth, smooth: smooth, reduceMotion: reduceMotion,
                  onDirection: press, onOK: ok, onRightSoft: rightSoft)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x1A1A1D), Color(hex: 0x2B2B30)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.35), radius: 1, y: -1)
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private var shell: some View {
        RoundedRectangle(cornerRadius: 46, style: .continuous)
            .fill(LinearGradient(colors: [style.top, style.bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.0), .black.opacity(0.12)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 46, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1.5).blendMode(.overlay))
            .overlay(RoundedRectangle(cornerRadius: 46, style: .continuous).strokeBorder(.black.opacity(0.18), lineWidth: 1).padding(-0.5))
            .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 22)
            .shadow(color: style.bottom.opacity(0.4), radius: 6, x: 0, y: 4)
    }

    private var topDetails: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<6, id: \.self) { _ in
                    Capsule().fill(.black.opacity(0.35)).frame(width: 14, height: 4)
                        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5).offset(y: 0.5))
                }
            }
            HStack {
                Circle()
                    .fill(ledColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: ledColor.opacity(0.9), radius: phase == .playing ? 4 : 0)
                    .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 0.5))
                Spacer()
                Text("iAnguis")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(style.label.opacity(0.85))
                    .shadow(color: .white.opacity(0.25), radius: 0, y: 1)
                Spacer()
                Circle().fill(.clear).frame(width: 7, height: 7)
            }
            .padding(.horizontal, 12)
        }
        .accessibilityHidden(true)
    }

    private var ledColor: Color {
        switch phase {
        case .playing: return Color(hex: 0x6CFF6C)
        case .paused: return Color(hex: 0xFFB238)
        case .over, .won: return Color(hex: 0xFF4D4D)
        case .ready: return .black.opacity(0.3)
        }
    }

    private var softKeys: some View {
        HStack {
            SoftKey(icon: "gearshape.fill", style: style, label: t("Definições", "Settings")) {
                model.pause()
                model.showSettings = true
            }
            Spacer()
            SoftKey(icon: rightIcon, style: style, label: rightLabel, action: rightSoft)
        }
        .padding(.horizontal, 6)
    }

    private var rightIcon: String {
        switch phase {
        case .ready: return "play.fill"
        case .playing: return "pause.fill"
        case .paused: return "xmark"
        case .over, .won: return "list.bullet"
        }
    }
    private var rightLabel: String {
        switch phase {
        case .ready: return t("Jogar", "Play")
        case .playing: return t("Pausa", "Pause")
        case .paused: return t("Terminar partida", "End round")
        case .over, .won: return t("Menu", "Menu")
        }
    }
    private var centerIcon: String {
        switch phase {
        case .ready, .paused, .over, .won: return "play.fill"
        case .playing: return "pause.fill"
        }
    }
    private var centerLabel: String {
        switch phase {
        case .ready: return t("Jogar", "Play")
        case .playing: return t("Pausa", "Pause")
        case .paused: return t("Continuar", "Resume")
        case .over, .won: return t("Jogar de novo", "Play again")
        }
    }

    // MARK: Actions

    private func press(_ direction: Direction) {
        switch phase {
        case .playing:
            model.turn(direction)
        case .ready:
            if direction == .left || direction == .right {
                model.cycleMode(direction == .left ? -1 : 1)
                SoundBoard.shared.play(.click)
            }
        default:
            break
        }
    }

    private func ok() {
        switch phase {
        case .ready: start()
        case .playing: model.pause()
        case .paused: model.resume()
        case .over, .won: if model.resultVisible { start() }
        }
    }

    private func rightSoft() {
        switch phase {
        case .ready: start()
        case .playing: model.pause()
        case .paused: model.menu()
        case .over, .won: if model.resultVisible { model.menu() }
        }
    }

    private func start() {
        SoundBoard.shared.play(.start)
        model.start(model.selectedMode)
    }
}

// MARK: LCD

private struct LCDScreen: View {
    let model: GameModel
    let palette: LCDPalette
    let boardWidth: CGFloat
    let smooth: Bool
    let reduceMotion: Bool
    let onDirection: (Direction) -> Void
    let onOK: () -> Void
    let onRightSoft: () -> Void
    @Environment(\.loc) private var t
    @State private var swipeAnchor: CGPoint?
    @State private var swipeUsed = false

    private var game: SnakeGame { model.game }
    private var ink: Color { palette.ink }
    /// Text and menus inside the LCD grow with the screen, so they stay readable on a 13" iPad.
    private var scale: CGFloat { max(1, min(1.8, boardWidth / 330)) }

    var body: some View {
        VStack(spacing: 5) {
            statusRow
            hud
            ZStack {
                BoardView(model: model, palette: palette, smooth: smooth, reduceMotion: reduceMotion,
                          active: !model.showSplash && !model.showSettings && game.phase != .paused && !model.resultVisible)
                overlay
                    .frame(width: boardWidth / scale, height: boardWidth / BoardView.aspect / scale)
                    .scaleEffect(scale)
            }
            .frame(width: boardWidth, height: boardWidth / BoardView.aspect)
            .contentShape(Rectangle())
            .gesture(swipe)
            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [palette.back, palette.backDeep], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            // Glass glare across the panel.
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(stops: [.init(color: .white.opacity(0.22), location: 0), .init(color: .white.opacity(0.0), location: 0.45)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .allowsHitTesting(false)
        )
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.black.opacity(0.35), lineWidth: 2))
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            PixelIcon(rows: PixelIcon.signal, pixel: 1.5 * scale, color: ink)
            LCDText(game.phase == .ready ? model.selectedMode.title(t).uppercased() : game.mode.title(t).uppercased(), pixel: 1.25 * scale, color: ink)
            Spacer()
            if game.phase != .ready && game.mode.accelerates {
                LCDText(t("NÍVEL \(game.level)", "LEVEL \(game.level)"), pixel: 1.25 * scale, color: ink)
            }
            PixelIcon(rows: PixelIcon.battery, pixel: 1.5 * scale, color: ink)
        }
        .accessibilityElement(children: .combine)
    }

    private var hud: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                LCDText(t("PONTOS", "SCORE"), pixel: 1.1 * scale, color: ink.opacity(0.75))
                LCDText(String(format: "%04d", min(game.score, 9999)), pixel: 2.6 * scale, color: ink)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(t("Pontos", "Score")): \(game.score)")
            Spacer()
            if game.phase == .playing && game.combo >= 2 {
                ComboBadge(combo: game.combo, ink: ink, back: palette.back)
                    .scaleEffect(scale)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                LCDText(t("RECORDE", "BEST"), pixel: 1.1 * scale, color: ink.opacity(0.75))
                LCDText(String(format: "%04d", min(model.best, 9999)), pixel: 2.6 * scale, color: ink)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(t("Recorde", "Best")): \(model.best)")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: game.combo)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            LCDText(t("OPÇÕES", "OPTIONS"), pixel: 1.2 * scale, color: ink)
            Spacer()
            if let bonus = game.bonus, game.phase == .playing {
                HStack(spacing: 4) {
                    PixelIcon(rows: ["#.#.#", ".###.", "##.##", ".###.", "#.#.#"], pixel: 1.4 * scale, color: ink)
                    HStack(spacing: 1.5) {
                        ForEach(0..<10, id: \.self) { index in
                            Rectangle().fill(ink.opacity(index < (bonus.stepsLeft * 10 + Bonus.lifetime - 1) / Bonus.lifetime ? 1 : 0.1))
                                .frame(width: 3.5 * scale, height: 5 * scale)
                        }
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(t("Bicho bónus no ecrã", "Bonus critter on screen"))
            }
            Spacer()
            LCDText(rightLabel, pixel: 1.2 * scale, color: ink)
        }
        .frame(height: 13 * scale)
    }

    private var rightLabel: String {
        switch game.phase {
        case .ready: return t("JOGAR", "PLAY")
        case .playing: return t("PAUSA", "PAUSE")
        case .paused: return t("SAIR", "QUIT")
        case .over, .won: return model.resultVisible ? "MENU" : ""
        }
    }

    /// Swipes keep turning while the finger moves, so quick zig-zags need only one gesture.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let anchor = swipeAnchor ?? value.startLocation
                let dx = value.location.x - anchor.x, dy = value.location.y - anchor.y
                guard max(abs(dx), abs(dy)) > 20 else { return }
                let direction: Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                swipeAnchor = value.location
                if game.phase == .playing {
                    onDirection(direction)
                } else if game.phase == .ready, !swipeUsed {
                    swipeUsed = true
                    onDirection(direction)
                }
            }
            .onEnded { _ in
                swipeAnchor = nil
                swipeUsed = false
            }
    }

    @ViewBuilder private var overlay: some View {
        switch game.phase {
        case .ready:
            MenuOverlay(model: model, palette: palette, reduceMotion: reduceMotion, onPlay: onOK)
                .transition(.opacity)
        case .paused:
            PauseOverlay(model: model, palette: palette, onResume: onOK, onQuit: onRightSoft)
                .transition(.opacity)
        case .over, .won:
            if model.resultVisible {
                ResultOverlay(model: model, palette: palette, reduceMotion: reduceMotion, onAgain: onOK, onMenu: onRightSoft)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        case .playing:
            EmptyView()
        }
    }
}

private struct ComboBadge: View {
    let combo: Int
    let ink: Color
    let back: Color

    var body: some View {
        HStack(spacing: 3) {
            LCDText("COMBO", pixel: 1.1, color: back)
            LCDText("×\(combo)", pixel: 1.8, color: back)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(ink, in: RoundedRectangle(cornerRadius: 3))
        .accessibilityElement()
        .accessibilityLabel("Combo \(combo)")
    }
}

// MARK: Screens inside the LCD

private struct LCDButton: View {
    let title: String
    let primary: Bool
    let palette: LCDPalette
    var blink = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if primary {
                    LCDText("▶", pixel: 1.8, color: palette.back)
                        .phaseAnimator([1.0, 0.25]) { view, value in view.opacity(blink ? value : 1) } animation: { _ in .easeInOut(duration: 0.5) }
                }
                LCDText(title, pixel: 1.8, color: primary ? palette.back : palette.ink)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background {
                if primary {
                    RoundedRectangle(cornerRadius: 6).fill(palette.ink)
                } else {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(palette.ink, lineWidth: 2)
                }
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(title.capitalized)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap(); SoundBoard.shared.play(.click) }
            }
    }
}

private struct MenuOverlay: View {
    let model: GameModel
    let palette: LCDPalette
    let reduceMotion: Bool
    let onPlay: () -> Void
    @Environment(\.loc) private var t

    var body: some View {
        GeometryReader { geo in
            let title = min(5, geo.size.width / 52)
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                LCDText("iANGUIS", pixel: title, color: palette.ink)
                    .phaseAnimator([0.0, -4.0]) { view, value in view.offset(y: reduceMotion ? 0 : value) } animation: { _ in .easeInOut(duration: 0.9) }
                Text(t("A COBRA DE BOLSO", "THE POCKET SNAKE"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.5)
                    .foregroundStyle(palette.ink.opacity(0.8))
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    arrow("◀", t("Modo anterior", "Previous mode")) { model.cycleMode(-1) }
                    LCDText(modeTitle, pixel: min(2.4, (geo.size.width - 110) / CGFloat(max(1, modeTitle.count * 6))), color: palette.ink)
                        .frame(maxWidth: .infinity)
                        .id(model.selectedMode)
                        .transition(.push(from: .trailing))
                    arrow("▶", t("Modo seguinte", "Next mode")) { model.cycleMode(1) }
                }
                .animation(.snappy(duration: 0.25), value: model.selectedMode)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(t("Modo: \(model.selectedMode.title(t))", "Mode: \(model.selectedMode.title(t))"))
                Text(model.selectedMode.blurb(t))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 30)
                HStack(spacing: 6) {
                    LCDText("♥", pixel: 1.4, color: palette.ink)
                    LCDText("\(model.selectedMode == .daily ? t("HOJE", "TODAY") : t("RECORDE", "BEST")) \(model.best(for: model.selectedMode))", pixel: 1.4, color: palette.ink)
                    if model.selectedMode == .daily {
                        LCDText("· \(t("SÉRIE", "STREAK")) \(model.dailyStreak)", pixel: 1.4, color: palette.ink)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                HStack(spacing: 8) {
                    LCDButton(title: t("JOGAR", "PLAY"), primary: true, palette: palette, blink: !reduceMotion, action: onPlay)
                    if GameCenter.shared.enabled {
                        Button { GameCenter.shared.showLeaderboards() } label: {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(palette.ink)
                                .frame(width: 48, height: 44)
                                .background(RoundedRectangle(cornerRadius: 6).strokeBorder(palette.ink, lineWidth: 2))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(t("Rankings do Game Center", "Game Center leaderboards"))
                    }
                }
                Text(t("Desliza no ecrã ou usa as setas", "Swipe the screen or use the arrows"))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.7))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(palette.back.opacity(0.55))
    }

    private var modeTitle: String { model.selectedMode.title(t).uppercased() }

    private func arrow(_ glyph: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LCDText(glyph, pixel: 2.2, color: palette.ink).frame(width: 44, height: 44)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

private struct PauseOverlay: View {
    let model: GameModel
    let palette: LCDPalette
    let onResume: () -> Void
    let onQuit: () -> Void
    @Environment(\.loc) private var t

    var body: some View {
        VStack(spacing: 14) {
            LCDText(t("PAUSA", "PAUSED"), pixel: 4, color: palette.ink)
                .phaseAnimator([1.0, 0.35]) { view, value in view.opacity(value) } animation: { _ in .easeInOut(duration: 0.7) }
            Text(t("\(model.game.score) pontos · \(model.game.snake.count) segmentos", "\(model.game.score) points · \(model.game.snake.count) segments"))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.ink)
            LCDButton(title: t("CONTINUAR", "RESUME"), primary: true, palette: palette, action: onResume)
            LCDButton(title: t("TERMINAR", "END ROUND"), primary: false, palette: palette, action: onQuit)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.back.opacity(0.86))
    }
}

private struct ResultOverlay: View {
    let model: GameModel
    let palette: LCDPalette
    let reduceMotion: Bool
    let onAgain: () -> Void
    let onMenu: () -> Void
    @Environment(\.loc) private var t
    @State private var shown = 0

    private var game: SnakeGame { model.game }

    var body: some View {
        VStack(spacing: 10) {
            LCDText(game.phase == .won ? t("VITÓRIA!", "YOU WIN!") : t("FIM DO JOGO", "GAME OVER"), pixel: 3, color: palette.ink)
            if model.isNewRecord {
                LCDText(t("NOVO RECORDE!", "NEW RECORD!"), pixel: 1.7, color: palette.back)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(palette.ink, in: RoundedRectangle(cornerRadius: 3))
                    .phaseAnimator([1.0, 0.3]) { view, value in view.opacity(reduceMotion ? 1 : value) } animation: { _ in .easeInOut(duration: 0.35) }
            }
            LCDText(String(format: "%04d", shown), pixel: 5, color: palette.ink)
                .accessibilityLabel("\(game.score) \(t("pontos", "points"))")
            HStack(spacing: 14) {
                stat(t("MAÇÃS", "APPLES"), game.apples)
                stat(t("TAMANHO", "LENGTH"), game.snake.count)
                stat(t("NÍVEL", "LEVEL"), game.level)
            }
            ForEach(model.newlyUnlocked) { cover in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [cover.style.top, cover.style.bottom], startPoint: .top, endPoint: .bottom))
                        .frame(width: 16, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(palette.ink, lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 1) {
                        LCDText(t("NOVA CAPA!", "NEW COVER!"), pixel: 1.3, color: palette.ink)
                        Text(cover.name(t)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(palette.ink)
                    }
                }
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(palette.ink, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
            }
            HStack(spacing: 8) {
                LCDButton(title: t("OUTRA", "AGAIN"), primary: true, palette: palette, blink: !reduceMotion, action: onAgain)
                LCDButton(title: "MENU", primary: false, palette: palette, action: onMenu)
            }
            .padding(.top, 4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.back.opacity(0.9))
        .task {
            let target = game.score
            guard target > 0, !reduceMotion else { shown = target; return }
            let steps = min(30, target / 10)
            for index in 1...max(1, steps) {
                try? await Task.sleep(for: .milliseconds(26))
                shown = target * index / max(1, steps)
            }
            shown = target
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            LCDText(title, pixel: 1.1, color: palette.ink.opacity(0.75))
            LCDText("\(value)", pixel: 2, color: palette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.capitalized): \(value)")
    }
}

// MARK: Physical keys

private struct SoftKey: View {
    let icon: String
    let style: CoverStyle
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(style.keySymbol)
                .frame(width: 70, height: 36)
                .background(
                    Capsule().fill(LinearGradient(colors: [style.key.opacity(0.85), style.key], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.45), radius: 0, y: 3)
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .frame(minHeight: 44)
    }
}

/// A round four-way key with a centre button. Acts on touch-down and tilts towards the pressed side.
private struct NavPad: View {
    let size: CGFloat
    let style: CoverStyle
    let centerIcon: String
    let centerLabel: String
    let onDirection: (Direction) -> Void
    let onCenter: () -> Void
    @Environment(\.loc) private var t
    @State private var pressed: Region?

    enum Region: Equatable { case direction(Direction), center }

    var body: some View {
        let core = size * 0.36
        ZStack {
            Circle()
                .fill(.black.opacity(0.22))
                .frame(width: size + 12, height: size + 12)
                .blur(radius: 0.5)
            Circle()
                .fill(LinearGradient(colors: [style.key.opacity(0.78), style.key], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.5), radius: 0, y: 5)
            ForEach([Direction.up, .right, .down, .left], id: \.self) { direction in
                chevron(direction)
            }
            Circle()
                .fill(LinearGradient(colors: [style.accent, style.accent.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                .frame(width: core, height: core)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 0, y: pressed == .center ? 1 : 4)
                .overlay(
                    Image(systemName: centerIcon)
                        .font(.system(size: core * 0.32, weight: .black))
                        .foregroundStyle(style.key)
                        .contentTransition(.symbolEffect(.replace))
                )
                .scaleEffect(pressed == .center ? 0.9 : 1)
        }
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(tilt.angle), axis: tilt.axis, perspective: 0.6)
        .animation(.spring(response: 0.18, dampingFraction: 0.55), value: pressed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let region = region(at: value.location)
                    guard region != pressed else { return }
                    pressed = region
                    Haptics.tap()
                    switch region {
                    case .center: onCenter()
                    case .direction(let direction): onDirection(direction)
                    }
                }
                .onEnded { _ in pressed = nil }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("Teclas de direção", "Direction keys"))
        .accessibilityHint(centerLabel)
        .accessibilityAction(named: centerLabel) { onCenter() }
        .accessibilityAction(named: t("Cima", "Up")) { onDirection(.up) }
        .accessibilityAction(named: t("Baixo", "Down")) { onDirection(.down) }
        .accessibilityAction(named: t("Esquerda", "Left")) { onDirection(.left) }
        .accessibilityAction(named: t("Direita", "Right")) { onDirection(.right) }
    }

    private func chevron(_ direction: Direction) -> some View {
        let distance = size * 0.34
        let isPressed = pressed == .direction(direction)
        let name: String
        switch direction {
        case .up: name = "chevron.up"
        case .down: name = "chevron.down"
        case .left: name = "chevron.left"
        case .right: name = "chevron.right"
        }
        return Image(systemName: name)
            .font(.system(size: size * 0.13, weight: .black))
            .foregroundStyle(style.keySymbol.opacity(isPressed ? 1 : 0.8))
            .shadow(color: style.keySymbol.opacity(isPressed ? 0.8 : 0), radius: 6)
            .offset(x: CGFloat(direction.delta.x) * distance, y: CGFloat(direction.delta.y) * distance)
            .scaleEffect(isPressed ? 0.88 : 1)
    }

    private func region(at point: CGPoint) -> Region {
        let dx = point.x - size / 2, dy = point.y - size / 2
        if hypot(dx, dy) < size * 0.19 { return .center }
        if abs(dx) > abs(dy) { return .direction(dx > 0 ? .right : .left) }
        return .direction(dy > 0 ? .down : .up)
    }

    private var tilt: (angle: Double, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) {
        guard case .direction(let direction) = pressed else { return (0, (1, 0, 0)) }
        switch direction {
        case .up: return (9, (1, 0, 0))
        case .down: return (-9, (1, 0, 0))
        case .left: return (-9, (0, 1, 0))
        case .right: return (9, (0, 1, 0))
        }
    }
}
