import SwiftUI

/// The window that appears when the user selects **About QuickText** from the menu.
/// It is referenced from `QuickTextApp` (the Settings scene) so it must be visible to the app target.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 15) {
            // App icon – uses a system symbol that works on all macOS versions.
            Image(systemName: "note.text")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            // App name
            Text("QuickText")
                .font(.headline)

            // Version line – you can adjust the version string programmatically if you wish.
            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            // Copyright information
            Text("""
                Copyright © 2026 gocodecloud@cp-soft.com
                All rights reserved.
                """)
                .font(.caption)
                .multilineTextAlignment(.center)

            // Link to the website (use HTTPS to avoid App Store warnings)
            Link("Visit Website", destination: URL(string: "https://gocodecloud.com")!)
                .font(.caption)
        }
        .padding(30)
        .frame(minWidth: 300, minHeight: 200)
    }
}
