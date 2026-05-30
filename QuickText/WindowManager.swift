import SwiftUI
import SwiftData
import AppKit

class WindowManager: NSObject {
    static let shared = WindowManager()
    private var panel: NSPanel?
    private var statusItem: NSStatusItem? // The toggle icon
    
    // MARK: - Welcome‑screen flag handling
    
    // UserDefaults key used throughout the app
    private let showWelcomeKey = "showWelcomeOnStartup"
    
    /// Returns the current stored value for the welcome‑screen flag.
    /// If the key has never been written, we treat the default as `true`
    /// (so the welcome screen shows on first launch).
    private var showWelcomeOnStartup: Bool {
        get {
            // `bool(forKey:)` returns `false` when the key is missing,
            // so we need to fall back to the intended default (`true`).
            if UserDefaults.standard.object(forKey: showWelcomeKey) == nil {
                return true // first launch – show the welcome screen
            }
            return UserDefaults.standard.bool(forKey: showWelcomeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showWelcomeKey)
        }
    }
    
    private var hasCheckedWelcome = false
    
    // MARK: - Init
    
    override init() {
        super.init()
        setupStatusItem() // Creates the menu bar icon
        createPanel()
        
        // Requirement 2.1: Agent Mode - Hide from Dock and Cmd+Tab
        NSApp.setActivationPolicy(.accessory)
        
        // Observe when the app finishes launching
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showWelcomeWindowIfNeeded),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }
    
    // MARK: - Welcome‑screen handling
    
    @objc private func showWelcomeWindowIfNeeded() {
        guard !hasCheckedWelcome else { return }
        hasCheckedWelcome = true
        
        // Use the computed property instead of @AppStorage
        if showWelcomeOnStartup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Look for an existing welcome window
                if let windowScene = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("welcome") == true }) {
                    windowScene.makeKeyAndOrderFront(nil)
                } else {
                    // No welcome window yet – create one
                    let welcomeWindow = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
                        styleMask: [.titled, .closable],
                        backing: .buffered,
                        defer: false
                    )
                    welcomeWindow.identifier = NSUserInterfaceItemIdentifier("welcome")
                    welcomeWindow.center()
                    welcomeWindow.setFrameAutosaveName("Welcome")
                    welcomeWindow.contentView = NSHostingView(rootView: WelcomeView())
                    welcomeWindow.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
    
    // MARK: - Status‑item handling
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Toggle QuickText")
            button.target = self
            button.action = #selector(toggleWindow)
        }
    }
    
    @objc func toggleWindow() {
        if let panel = panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }
    
    // MARK: - Panel creation
    
    private func createPanel() {
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.nonactivatingPanel, .resizable, .titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        newPanel.title = "QuickText"
        
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.isMovableByWindowBackground = true
        newPanel.isReleasedWhenClosed = false
        newPanel.setFrameAutosaveName("QuickTextMainWindow")
        newPanel.setFrameUsingName("QuickTextMainWindow")
        
        // Requirement 2.3: Space‑agnostic – Stay visible across all Spaces
        newPanel.collectionBehavior = [.canJoinAllSpaces]
        
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        
        let contentView = ContentView()
            .modelContainer(for: Note.self)
        
        newPanel.contentView = NSHostingView(rootView: contentView)
        self.panel = newPanel
    }
    
    func showPanel() {
        if panel == nil { createPanel() }
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Font changes
    
    // FIX: The correct way to handle NSFontManager changes
    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        
        // 1. Read current font from UserDefaults
        let currentFontName = UserDefaults.standard.string(forKey: "fontName") ?? "Helvetica"
        let currentFontSize = UserDefaults.standard.double(forKey: "fontSize")
        let size = currentFontSize > 0 ? CGFloat(currentFontSize) : 13.0
        
        let currentFont = NSFont(name: currentFontName, size: size) ?? NSFont.systemFont(ofSize: size)
        
        // 2. Ask the font manager to convert our current font to the user's new selection
        let newFont = fontManager.convert(currentFont)
        
        // 3. Save back to AppStorage/UserDefaults
        UserDefaults.standard.set(newFont.fontName, forKey: "fontName")
        UserDefaults.standard.set(Double(newFont.pointSize), forKey: "fontSize")
    }
    
    // MARK: - Public helper (optional)
    
    /// Call this from a Settings view or elsewhere to toggle the welcome‑screen flag.
    func setShowWelcomeOnStartup(_ value: Bool) {
        showWelcomeOnStartup = value
    }
}

// MARK: - Helper to close the welcome window instantly

extension WindowManager {
    /// Finds any open welcome window (identifier contains “welcome”) and closes it.
    func dismissWelcomeIfNeeded() {
        if let welcome = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("welcome") == true }) {
            welcome.close()
        }
    }
}
