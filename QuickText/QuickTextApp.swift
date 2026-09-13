import SwiftUI
import SwiftData
import KeyboardShortcuts
import Combine
import AppKit

@main
struct QuickTextApp: App {
    init() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.cp-soft.QuickText"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            let alert = NSAlert()
            alert.messageText = "QuickText is already running."
            alert.runModal()
            exit(0)
        }

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
