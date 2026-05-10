import SwiftUI
import KeyboardShortcuts
import AppKit

struct WelcomeView: View {
    @StateObject private var launchManager = LaunchManager()
    
    // ---- FIX: Use the same UserDefaults key as WindowManager ----
    @AppStorage("showWelcomeOnStartup") private var showWelcome = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to QuickText")
                .font(.largeTitle)
            
            Text("QuickText lives in your menu bar; just click the icon when you need to make a note. Any changes you make will be automatically saved.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Open QuickText with this shortcut:")
                    
                    KeyboardShortcuts.Recorder(for: .toggleQuickText)
                }
                
                Toggle("Start QuickText when I log in", isOn: $launchManager.isEnabled)
                Toggle("Show this window when QuickText is started", isOn: $showWelcome)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .cornerRadius(10)

            Button("OK") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 500)
    }
}
