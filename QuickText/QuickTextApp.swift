import SwiftUI
import SwiftData
import KeyboardShortcuts
import Combine

@main
struct QuickTextApp: App {
    init() {
        _ = WindowManager.shared
        
        KeyboardShortcuts.onKeyDown(for: .toggleQuickText) {
            WindowManager.shared.toggleWindow()
        }
        
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    var body: some Scene {
        Window("Welcome", id: "welcome") {
            WelcomeView()
        }
        .defaultLaunchBehavior(.suppressed)
//        .windowResizability(.contentSize)
//        .restorationBehavior(.disabled)

        Window("About QuickText", id: "about") {
            AboutView()
        }
        .defaultLaunchBehavior(.suppressed)
//        .windowResizability(.contentSize)
//        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
        }
        .defaultLaunchBehavior(.suppressed)
//        .restorationBehavior(.disabled)
        
    }
}
