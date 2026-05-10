import SwiftUI
import SwiftData
import AppKit

// Helper for the "Vibrancy" (blur) effect
struct ContentVisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

struct ContentView: View {
    @Query private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    // Preferences
    @AppStorage("fontName") private var fontName = "Helvetica"
    @AppStorage("fontSize") private var fontSize = 13.0
    @AppStorage("isHUDStyle") private var isHUDStyle = false
    @AppStorage("showWelcomeOnStartup") private var showWelcomeOnStartup = true

    var body: some View {
        ZStack {
            if isHUDStyle {
                ContentVisualEffect(material: .hudWindow)
                    .ignoresSafeArea()
            } else {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if let note = notes.first {
                    TextEditor(text: Binding(
                        get: { note.content },
                        set: { note.content = $0 }
                    ))
                    .font(.custom(fontName, size: CGFloat(fontSize)))
                    // IMPORTANT: This .id forces SwiftUI to redraw the TextEditor
                    // whenever the font or size changes, fixing the "font not updating" bug.
                    .id("\(fontName)-\(fontSize)")
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack {
                    Menu {
                        SettingsLink()
                        Button("About QuickText") { openWindow(id: "about") }
                        Button("Send Feedback...") { FeedbackManager.sendFeedback() }
                        Button("Welcome") { openWindow(id: "welcome") }
                        Divider()
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()
                }
                .padding(8)
                .background(Color.primary.opacity(0.05))
            }
        }
        .onAppear {
            if notes.isEmpty {
                modelContext.insert(Note(content: ""))
            }
        }
        .frame(minWidth: 300, minHeight: 200)
    }
}
