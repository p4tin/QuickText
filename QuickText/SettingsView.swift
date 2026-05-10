import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @StateObject private var launchManager = LaunchManager()
    
    // Preferences persisted automatically to macOS UserDefaults
    @AppStorage("stayOnTop") private var stayOnTop = true
    @AppStorage("isHUDStyle") private var isHUDStyle = false
    @AppStorage("fontName") private var fontName = "Helvetica"
    @AppStorage("fontSize") private var fontSize = 14.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. Shortcut Section
            HStack {
                Text("Shortcut:")
                    .frame(width: 80, alignment: .trailing)
                KeyboardShortcuts.Recorder(for: .toggleQuickText)
            }
            Text("When pressed, this key combination will bring QuickText's window to the foreground.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 90)

            // 2. Window Options
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Window:")
                        .frame(width: 80, alignment: .trailing)
                    Toggle("Stay on top until dismissed", isOn: $stayOnTop)
                }
                
                HStack {
                    Spacer().frame(width: 85)
                    Toggle("HUD style window", isOn: $isHUDStyle)
                }
            }

            // 3. Font Section
            HStack {
                Text("Font:")
                    .frame(width: 80, alignment: .trailing)
                Text("\(fontName) \(Int(fontSize)).0")
                Spacer()
                Button("Choose Font") {
                    openFontPicker()
                }
            }

            // 4. Startup Section
            HStack {
                Text("Startup:")
                    .frame(width: 80, alignment: .trailing)
                Toggle("Start QuickText when I log in", isOn: $launchManager.isEnabled)
            }

            // 5. Footer
            HStack {
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding(25)
        .frame(width: 450)
    }

    private func openFontPicker() {
        let fontManager = NSFontManager.shared
        fontManager.target = WindowManager.shared
        
        // Tell the font panel what our current font is
        let currentFont = NSFont(name: fontName, size: CGFloat(fontSize)) ?? .systemFont(ofSize: CGFloat(fontSize))
        fontManager.setSelectedFont(currentFont, isMultiple: false)
        
        let fontPanel = fontManager.fontPanel(true)
        fontPanel?.makeKeyAndOrderFront(nil)
    }
}
