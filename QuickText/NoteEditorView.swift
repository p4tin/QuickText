import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

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

/// The Backup/Restore confirmation dialog + error alerts, split out of
/// `NoteEditorView.body` into their own `ViewModifier` — combined with the
/// rest of that view's modifier chain, this much dialog/alert content
/// inline pushes the type-checker past what it can solve in one pass.
private struct BackupRestoreAlerts: ViewModifier {
    @Binding var pendingRestoreDocument: BackupDocument?
    @Binding var backupErrorMessage: String?
    @Binding var restoreErrorMessage: String?
    let onConfirmRestore: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Replace all notes and folders?",
                isPresented: Binding(
                    get: { pendingRestoreDocument != nil },
                    set: { isPresented in if !isPresented { pendingRestoreDocument = nil } }
                ),
                presenting: pendingRestoreDocument
            ) { _ in
                Button("Restore", role: .destructive) {
                    onConfirmRestore()
                }
                Button("Cancel", role: .cancel) {
                    pendingRestoreDocument = nil
                }
            } message: { _ in
                Text("This replaces every note and folder currently in QuickText with the contents of the backup. This cannot be undone.")
            }
            .alert(
                "Backup Failed",
                isPresented: Binding(
                    get: { backupErrorMessage != nil },
                    set: { isPresented in if !isPresented { backupErrorMessage = nil } }
                ),
                presenting: backupErrorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .alert(
                "Restore Failed",
                isPresented: Binding(
                    get: { restoreErrorMessage != nil },
                    set: { isPresented in if !isPresented { restoreErrorMessage = nil } }
                ),
                presenting: restoreErrorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }
}

struct NoteEditorView: View {
    var note: Note?

    /// So Backup/Restore can select a fallback note after a restore
    /// replaces the entire tree — owned by `ContentView`, same as
    /// `SidebarView`'s binding.
    @Binding var selectedNoteID: UUID?

    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    // Preferences
    @AppStorage("fontName") private var fontName = "Helvetica"
    @AppStorage("fontSize") private var fontSize = 13.0
    @AppStorage("isHUDStyle") private var isHUDStyle = false

    /// A backup file picked via "Restore…" that's already been read and
    /// validated (see `validateBackup`); non-nil drives the "replace
    /// everything?" confirmation dialog. Nothing in the store is touched
    /// until that's confirmed.
    @State private var pendingRestoreDocument: BackupDocument?

    /// Non-nil while a Backup/Restore error alert is up.
    @State private var backupErrorMessage: String?
    @State private var restoreErrorMessage: String?

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
                if let note {
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
                } else {
                    Text("No note selected")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack {
                    Menu {
                        SettingsLink()
                        Button("About QuickText") { openWindow(id: "about") }
                        Button("Send Feedback...") { FeedbackManager.sendFeedback() }
                        Button("Welcome") { openWindow(id: "welcome") }
                        Divider()
                        Button("Backup…") { presentBackupPanel() }
                        Button("Restore…") { presentRestorePanel() }
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
        .frame(minWidth: 300, minHeight: 200)
        .modifier(BackupRestoreAlerts(
            pendingRestoreDocument: $pendingRestoreDocument,
            backupErrorMessage: $backupErrorMessage,
            restoreErrorMessage: $restoreErrorMessage,
            onConfirmRestore: confirmRestore
        ))
    }

    /// Presents a save panel for "Backup…" and writes the archive on
    /// confirmation. Failures surface via `backupErrorMessage`; nothing is
    /// left on disk at the destination if the write fails partway (see
    /// `performBackup`).
    private func presentBackupPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "gz") ?? .data]
        panel.nameFieldStringValue = "QuickText Backup \(backupDateStamp()).tar.gz"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try performBackup(context: modelContext, to: url)
            } catch {
                backupErrorMessage = error.localizedDescription
            }
        }
    }

    private func backupDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    /// Presents an open panel for "Restore…". The selected file is read and
    /// validated immediately (`validateBackup`) — nothing in the store is
    /// touched yet. On success, `pendingRestoreDocument` drives the
    /// "replace everything?" confirmation dialog; on failure, an alert
    /// reports the error and the current tree is untouched either way.
    private func presentRestorePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "gz") ?? .data]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                pendingRestoreDocument = try validateBackup(at: url)
            } catch {
                restoreErrorMessage = error.localizedDescription
            }
        }
    }

    /// Called from the "Replace all notes and folders?" dialog's "Restore"
    /// button. Replaces the entire tree, then picks a fallback selection
    /// (same helper used after note/folder deletion) so the app is left on
    /// a valid note.
    private func confirmRestore() {
        guard let document = pendingRestoreDocument else { return }
        performRestore(document, context: modelContext)
        pendingRestoreDocument = nil
        selectedNoteID = resolveFallbackSelection(context: modelContext)
    }
}
