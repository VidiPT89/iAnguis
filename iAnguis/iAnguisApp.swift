import SwiftUI

@main struct iAnguisApp: App {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("language") private var language = "pt"

    init() {
        // Portuguese devices start in PT-PT, everyone else in English, until changed in Settings.
        let device = (Locale.preferredLanguages.first ?? "pt").hasPrefix("pt") ? "pt" : "en"
        UserDefaults.standard.register(defaults: ["sound": true, "haptics": true, "language": device])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.loc, Loc(pt: language == "pt"))
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
    }
}
