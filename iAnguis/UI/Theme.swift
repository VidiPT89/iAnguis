import SwiftUI

// MARK: Language

/// Picks the Portuguese or English string for the language chosen in Settings.
struct Loc {
    var pt: Bool
    func callAsFunction(_ pt: String, _ en: String) -> String { self.pt ? pt : en }
}

private struct LocKey: EnvironmentKey { static let defaultValue = Loc(pt: true) }
extension EnvironmentValues {
    var loc: Loc {
        get { self[LocKey.self] }
        set { self[LocKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

// MARK: LCD screens

struct LCDPalette {
    var back: Color
    var backDeep: Color
    var ink: Color
}

enum LCDStyle: String, CaseIterable, Identifiable {
    case green, amber, ice, mono
    var id: String { rawValue }
    var palette: LCDPalette {
        switch self {
        case .green: return LCDPalette(back: Color(hex: 0xB4CC74), backDeep: Color(hex: 0x9DB862), ink: Color(hex: 0x1F3318))
        case .amber: return LCDPalette(back: Color(hex: 0xF6BD58), backDeep: Color(hex: 0xE5A43E), ink: Color(hex: 0x3D1C04))
        case .ice: return LCDPalette(back: Color(hex: 0x9CD3E4), backDeep: Color(hex: 0x7FBFD4), ink: Color(hex: 0x0A2740))
        case .mono: return LCDPalette(back: Color(hex: 0xBFC3B8), backDeep: Color(hex: 0xA9AEA2), ink: Color(hex: 0x1B1D1F))
        }
    }
    func name(_ t: Loc) -> String {
        switch self {
        case .green: return t("Verde clássico", "Classic green")
        case .amber: return t("Âmbar", "Amber")
        case .ice: return t("Azul gelo", "Ice blue")
        case .mono: return t("Cinza", "Grey")
        }
    }
}

// MARK: Covers

struct CoverStyle {
    var top: Color
    var bottom: Color
    var key: Color
    var keySymbol: Color
    var accent: Color
    var label: Color
}

extension Cover {
    var style: CoverStyle {
        switch self {
        case .ember: return CoverStyle(top: Color(hex: 0xF07A2B), bottom: Color(hex: 0xC4500F), key: Color(hex: 0x1C1714), keySymbol: Color(hex: 0xFFD08A), accent: Color(hex: 0xFFC247), label: Color(hex: 0x2A1405))
        case .slate: return CoverStyle(top: Color(hex: 0x52677E), bottom: Color(hex: 0x2E3D50), key: Color(hex: 0x1A2330), keySymbol: Color(hex: 0xD8E4F0), accent: Color(hex: 0xFF6B52), label: Color(hex: 0xE4ECF5))
        case .lime: return CoverStyle(top: Color(hex: 0xA6D23F), bottom: Color(hex: 0x6E9E1E), key: Color(hex: 0x1F3311), keySymbol: Color(hex: 0xE9FFB8), accent: Color(hex: 0xFFE14D), label: Color(hex: 0x1B2D0B))
        case .ice: return CoverStyle(top: Color(hex: 0xE3EEF6), bottom: Color(hex: 0xA9C3D9), key: Color(hex: 0x34495E), keySymbol: Color(hex: 0xEAF6FF), accent: Color(hex: 0x2BB3E8), label: Color(hex: 0x22374B))
        case .cherry: return CoverStyle(top: Color(hex: 0xE33049), bottom: Color(hex: 0x9C0E26), key: Color(hex: 0x2B0710), keySymbol: Color(hex: 0xFFC2CC), accent: Color(hex: 0xFFD3DA), label: Color(hex: 0xFFE6EA))
        case .carbon: return CoverStyle(top: Color(hex: 0x34363B), bottom: Color(hex: 0x101114), key: Color(hex: 0x45484F), keySymbol: Color(hex: 0xF2F2F2), accent: Color(hex: 0xFF8A2A), label: Color(hex: 0xC9CDD4))
        case .aurora: return CoverStyle(top: Color(hex: 0x7A45D8), bottom: Color(hex: 0x1F9AA3), key: Color(hex: 0x1A1033), keySymbol: Color(hex: 0xD9FFF4), accent: Color(hex: 0x6CFFD2), label: Color(hex: 0xF1EBFF))
        case .gold: return CoverStyle(top: Color(hex: 0xF5D27A), bottom: Color(hex: 0xB9862A), key: Color(hex: 0x3B2808), keySymbol: Color(hex: 0xFFF1C9), accent: Color(hex: 0xFFFFFF), label: Color(hex: 0x3B2808))
        }
    }

    func name(_ t: Loc) -> String {
        switch self {
        case .ember: return t("Laranja iVidi", "iVidi Orange")
        case .slate: return t("Ardósia", "Slate")
        case .lime: return t("Lima", "Lime")
        case .ice: return t("Gelo", "Ice")
        case .cherry: return t("Cereja", "Cherry")
        case .carbon: return t("Carbono", "Carbon")
        case .aurora: return t("Aurora", "Aurora")
        case .gold: return t("Ouro", "Gold")
        }
    }

    func requirementText(_ t: Loc) -> String {
        switch requirement {
        case .free: return t("Disponível", "Available")
        case .apples(let n): return t("Come \(n) maçãs no total", "Eat \(n) apples in total")
        case .games(let n): return t("Joga \(n) partidas", "Play \(n) rounds")
        case .score(let n): return t("Faz \(n) pontos numa partida", "Score \(n) in one round")
        case .longest(let n): return t("Chega a \(n) segmentos", "Reach \(n) segments")
        case .bonus(let n): return t("Apanha \(n) bichos bónus", "Catch \(n) bonus critters")
        }
    }
}

// MARK: Modes

extension GameMode {
    func title(_ t: Loc) -> String {
        switch self {
        case .classic: return t("Clássico", "Classic")
        case .arcade: return "Arcade"
        case .maze: return t("Labirinto", "Maze")
        case .zen: return "Zen"
        }
    }
    func blurb(_ t: Loc) -> String {
        switch self {
        case .classic: return t("Paredes sólidas. Cada nível acelera.", "Solid walls. Every level speeds up.")
        case .arcade: return t("Atravessa as margens. Cada nível acelera.", "Wrap through the edges. Every level speeds up.")
        case .maze: return t("Muros pelo caminho. Atravessa as margens.", "Walls in your way. Wrap through the edges.")
        case .zen: return t("Sem paredes, ritmo constante. Só tu e a cobra.", "No walls, a steady pace. Just you and the snake.")
        }
    }
}
