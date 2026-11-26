import SwiftUI

/// Launch introduction: a pixel snake writes the name on a small LCD, then the credits fade in.
struct SplashView: View {
    let style: CoverStyle
    let palette: LCDPalette
    let reduceMotion: Bool
    let onFinish: () -> Void
    @Environment(\.loc) private var t
    @State private var start = ProcessInfo.processInfo.systemUptime
    static let duration = 3.4

    var body: some View {
        GeometryReader { geo in
        TimelineView(.animation(paused: reduceMotion)) { _ in
            let age = reduceMotion ? 2.5 : ProcessInfo.processInfo.systemUptime - start
            ZStack {
                LinearGradient(colors: [style.top, style.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                RadialGradient(colors: [.white.opacity(0.28), .clear], center: .init(x: 0.5, y: 0.38), startRadius: 0, endRadius: 360)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()
                    logo(age: age, width: min(560, max(270, min(geo.size.width, geo.size.height) * 0.5)))
                        .scaleEffect(0.86 + 0.14 * ease(min(1, age / 0.5)))
                        .opacity(min(1, age / 0.25))
                    Text(t("A cobra de bolso está de volta.", "The pocket snake is back."))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(style.label)
                        .padding(.top, 26)
                        .opacity(fade(age, from: 1.2))
                        .offset(y: 10 * (1 - fade(age, from: 1.2)))
                    Spacer()
                    credits
                        .opacity(fade(age, from: 1.5))
                        .offset(y: 14 * (1 - fade(age, from: 1.5)))
                        .padding(.bottom, 36)
                }
                .padding(24)
            }
        }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .task {
            SoundBoard.shared.play(.intro)
            try? await Task.sleep(for: .seconds(Self.duration))
            onFinish()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: t("Saltar", "Skip"), onFinish)
    }

    private func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private func fade(_ age: Double, from: Double) -> Double { ease(max(0, min(1, (age - from) / 0.5))) }

    private func logo(age: Double, width: CGFloat) -> some View {
        Canvas { context, size in
            let columns = 55, rows = 24
            let dot = size.width / CGFloat(columns)
            let lit = dot * 0.84
            var ghost = Path()
            for y in 0..<rows { for x in 0..<columns { ghost.addRect(CGRect(x: CGFloat(x) * dot, y: CGFloat(y) * dot, width: lit, height: lit)) } }
            context.fill(ghost, with: .color(palette.ink.opacity(0.07)))

            let travel = 1.3
            let headX = -6 + (Double(columns) + 16) * min(1, age / travel)
            let text = PixelFont.layout("iANGUIS")
            let left = (columns - text.width) / 2
            let blinkOff = age > travel && age < travel + 0.5 && Int((age - travel) * 8) % 2 == 1
            var ink = Path()
            if !blinkOff {
                for (x, y) in text.pixels where Double(left + x) < headX - 2 {
                    ink.addRect(CGRect(x: CGFloat(left + x) * dot, y: CGFloat(y + 2) * dot, width: lit, height: lit))
                }
            }
            // The snake runs along the bottom, its body rippling behind the head.
            if age < travel + 0.1 {
                for segment in 0..<14 {
                    let x = Int(headX) - segment
                    let wave = segment < 2 ? 0 : Int((sin(Double(x) * 0.7 - age * 10) * 1.2).rounded())
                    for thick in 0..<2 {
                        let rect = CGRect(x: CGFloat(x) * dot, y: CGFloat(19 + wave + thick) * dot, width: lit, height: lit)
                        if x >= 0 && x < columns { ink.addRect(rect) }
                    }
                }
                let eyeX = Int(headX) + 1
                if eyeX < columns { ink.addRect(CGRect(x: CGFloat(eyeX) * dot, y: CGFloat(19) * dot, width: lit, height: lit)) }
            }
            context.fill(ink, with: .color(palette.ink))
        }
        .frame(width: width, height: width * 24 / 55)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LinearGradient(colors: [palette.back, palette.backDeep], startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.black.opacity(0.3), lineWidth: 2))
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: 0x1C1C20)))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
        .accessibilityElement()
        .accessibilityLabel("iAnguis")
    }

    private var credits: some View {
        VStack(spacing: 10) {
            Text("Developed by David Arsénio Martins")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(style.label)
            VStack(spacing: 6) {
                Link(destination: URL(string: "https://ividi.dev/")!) {
                    Label("https://ividi.dev/", systemImage: "globe")
                }
                Link(destination: URL(string: "https://github.com/VidiPT89/")!) {
                    Label("https://github.com/VidiPT89/", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .font(.system(.footnote, design: .monospaced, weight: .medium))
            .foregroundStyle(style.label.opacity(0.85))
            .tint(style.label.opacity(0.85))
        }
    }
}
