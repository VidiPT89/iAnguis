import SwiftUI

struct SettingsView: View {
    let model: GameModel
    @AppStorage("language") private var language = "pt"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = true
    @AppStorage("cover") private var coverID = Cover.ember.rawValue
    @AppStorage("lcd") private var lcdID = LCDStyle.green.rawValue
    @AppStorage("motion") private var motion = "smooth"
    @Environment(\.dismiss) private var dismiss
    @State private var inspected: Cover?
    @State private var confirmReset = false

    private var t: Loc { Loc(pt: language == "pt") }
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }

    var body: some View {
        NavigationStack {
            Form {
                Section(t("Idioma e aparência", "Language and appearance")) {
                    Picker(t("Idioma", "Language"), selection: $language) {
                        Text("Português").tag("pt")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    Picker(t("Tema", "Theme"), selection: $appearance) {
                        Label(t("Sistema", "System"), systemImage: "circle.lefthalf.filled").tag("system")
                        Label(t("Claro", "Light"), systemImage: "sun.max.fill").tag("light")
                        Label(t("Escuro", "Dark"), systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    covers
                } header: {
                    Text(t("Capas", "Covers"))
                } footer: {
                    Text(inspected.map { "\($0.name(t)): \($0.requirementText(t))" } ?? t("Joga para desbloquear capas novas.", "Play to unlock new covers."))
                }

                Section(t("Ecrã", "Screen")) {
                    HStack(spacing: 12) {
                        ForEach(LCDStyle.allCases) { style in
                            Button { lcdID = style.rawValue } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(style.palette.back)
                                        .frame(height: 40)
                                        .overlay(PixelIcon(rows: ["#####....", "....#....", "....###.#"], pixel: 3, color: style.palette.ink))
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(lcdID == style.rawValue ? Color.accentColor : .black.opacity(0.15), lineWidth: lcdID == style.rawValue ? 3 : 1))
                                    Text(style.name(t)).font(.caption2).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(lcdID == style.rawValue ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    Picker(t("Movimento", "Movement"), selection: $motion) {
                        Text(t("Suave", "Smooth")).tag("smooth")
                        Text(t("Clássico, casa a casa", "Classic, cell by cell")).tag("classic")
                    }
                }

                if GameCenter.shared.enabled {
                    Section("Game Center") {
                        Button {
                            dismiss()
                            Task { try? await Task.sleep(for: .milliseconds(450)); GameCenter.shared.showLeaderboards() }
                        } label: {
                            Label(t("Ver rankings", "View leaderboards"), systemImage: "trophy.fill")
                        }
                    }
                }

                Section(t("Som e vibração", "Sound and haptics")) {
                    Toggle(isOn: $sound) { Label(t("Sons retro", "Retro sounds"), systemImage: "speaker.wave.2.fill") }
                    Toggle(isOn: $haptics) { Label(t("Vibração", "Haptics"), systemImage: "iphone.radiowaves.left.and.right") }
                }

                Section(t("Estatísticas", "Statistics")) {
                    stat(t("Partidas", "Rounds"), model.stats.games, "gamecontroller.fill")
                    stat(t("Maçãs comidas", "Apples eaten"), model.stats.apples, "applelogo")
                    stat(t("Bichos bónus", "Bonus critters"), model.stats.bonus, "ant.fill")
                    stat(t("Cobra mais comprida", "Longest snake"), model.stats.longest, "ruler.fill")
                    stat(t("Série do desafio do dia", "Daily challenge streak"), model.dailyStreak, "calendar")
                    ForEach(GameMode.allCases, id: \.self) { mode in
                        stat("\(mode == .daily ? t("Hoje", "Today") : t("Recorde", "Best")) · \(mode.title(t))", model.best(for: mode), "trophy.fill")
                    }
                    Button(t("Apagar estatísticas e recordes", "Reset statistics and records"), role: .destructive) { confirmReset = true }
                        .confirmationDialog(t("Apagar tudo?", "Reset everything?"), isPresented: $confirmReset, titleVisibility: .visible) {
                            Button(t("Apagar", "Reset"), role: .destructive) { model.resetStats() }
                        } message: {
                            Text(t("As capas conquistadas voltam a ficar bloqueadas.", "Earned covers will be locked again."))
                        }
                }

                Section(t("Como jogar", "How to play")) {
                    help("hand.draw.fill", t("Desliza no ecrã ou carrega nas setas para virar. Podes deslizar várias vezes sem levantar o dedo.", "Swipe the screen or press the arrows to turn. You can keep swiping without lifting your finger."))
                    help("flame.fill", t("Come a maçã depressa para subir o combo até ×5. Cada maçã vale 10 × combo.", "Eat apples quickly to build a combo up to ×5. Each apple is worth 10 × combo."))
                    help("ant.fill", t("A cada 5 maçãs aparece um bicho bónus. Quanto mais cedo o apanhares, mais pontos vale.", "Every 5 apples a bonus critter appears. The sooner you catch it, the more it is worth."))
                    help("square.grid.3x3.fill", t("Clássico: paredes sólidas. Arcade: atravessa as margens. Labirinto: muros pelo caminho. Zen: ritmo constante.", "Classic: solid walls. Arcade: wrap through the edges. Maze: walls in your way. Zen: a steady pace."))
                    help("calendar", t("Desafio do dia: um labirinto novo todos os dias, igual para todos, com ranking diário no Game Center. Joga todos os dias para aumentar a série.", "Daily challenge: a new maze every day, the same for everyone, with a daily Game Center leaderboard. Play every day to grow your streak."))
                    help("pause.fill", t("O jogo fica em pausa ao abrir as definições ou ao sair da app.", "The game pauses when you open settings or leave the app."))
                }

                Section(t("Sobre", "About")) {
                    LabeledContent("iAnguis", value: "\(t("Versão", "Version")) \(version)")
                    Text("Developed by David Arsénio Martins")
                    Link(destination: URL(string: "https://ividi.dev/")!) { Label("https://ividi.dev/", systemImage: "globe") }
                    Link(destination: URL(string: "https://github.com/VidiPT89/")!) { Label("https://github.com/VidiPT89/", systemImage: "chevron.left.forwardslash.chevron.right") }
                    Link(destination: URL(string: "https://github.com/VidiPT89/iAnguis/blob/main/PRIVACY.md")!) { Label(t("Política de privacidade", "Privacy policy"), systemImage: "hand.raised.fill") }
                    Text(t("Os teus recordes e preferências ficam neste dispositivo. Sem contas, sem anúncios, sem recolha de dados.", "Your scores and preferences stay on this device. No accounts, no ads, no data collection."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(t("Definições", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(t("Concluído", "Done")) { dismiss() }.fontWeight(.semibold) }
            }
        }
        .environment(\.loc, t)
    }

    private var covers: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
            ForEach(Cover.allCases) { cover in
                let unlocked = cover.isUnlocked(by: model.stats)
                let selected = coverID == cover.rawValue
                Button {
                    inspected = cover
                    if unlocked { withAnimation(.snappy) { coverID = cover.rawValue } }
                } label: {
                    VStack(spacing: 6) {
                        CoverThumb(style: cover.style)
                            .frame(height: 64)
                            .overlay {
                                if !unlocked {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.45))
                                        VStack(spacing: 4) {
                                            Image(systemName: "lock.fill").font(.callout.weight(.bold)).foregroundStyle(.white)
                                            ProgressView(value: cover.progress(for: model.stats))
                                                .tint(.white)
                                                .frame(width: 34)
                                        }
                                    }
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: selected ? 3 : 0).padding(-4))
                            .scaleEffect(selected ? 1.04 : 1)
                        Text(cover.name(t)).font(.caption2.weight(selected ? .bold : .regular)).foregroundStyle(unlocked ? .primary : .secondary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cover.name(t))
                .accessibilityValue(unlocked ? (selected ? t("Selecionada", "Selected") : "") : cover.requirementText(t))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
    }

    private func stat(_ title: String, _ value: Int, _ icon: String) -> some View {
        LabeledContent {
            Text("\(value)").monospacedDigit().fontWeight(.semibold)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private func help(_ icon: String, _ text: String) -> some View {
        Label { Text(text).font(.subheadline) } icon: { Image(systemName: icon).foregroundStyle(.tint) }
    }
}

/// A tiny console used to preview a cover.
private struct CoverThumb: View {
    let style: CoverStyle
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: [style.top, style.bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xB4CC74))
                    .frame(height: 22).padding(.horizontal, 8).padding(.top, 9)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.5), lineWidth: 1.5).padding(.horizontal, 8).padding(.top, 9))
            }
            .overlay(alignment: .bottom) {
                Circle().fill(style.key).frame(width: 16, height: 16).overlay(Circle().fill(style.accent).frame(width: 6, height: 6)).padding(.bottom, 8)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
    }
}
