import SwiftUI
import SwiftData

/// App shell: a `NavigationSplitView` pairing the notes/folders sidebar with
/// the editor for whichever note is currently selected.
///
/// This is Wave 2 / Task 6 of the multi-notes feature — see
/// `.claude/designs/multi-notes/design.md` ("Selection & Sidebar Visibility
/// Persistence") and `tasks.md` (Task 6) for the contract this implements.
/// The old single-note body (`TextEditor` + vibrancy + footer menu, and the
/// `ContentVisualEffect` helper) has moved to `NoteEditorView.swift`.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    /// Unfiltered so any note anywhere in the tree (not just root notes) can
    /// be resolved from a persisted `selectedNoteID`.
    @Query private var allNotes: [Note]

    /// The note currently shown in the editor pane, mirrored to/from
    /// `selectedNoteIDString` for persistence across launches.
    @State private var selectedNoteID: UUID?
    @AppStorage("selectedNoteIDString") private var selectedNoteIDString: String = ""

    /// Sidebar shown/hidden, mirrored to/from `NavigationSplitView`'s
    /// `columnVisibility`.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("sidebarVisible") private var sidebarVisible: Bool = true

    /// Guards the startup bootstrap (migration/prune/default-note + selection
    /// restore) so it only runs once, not on every `onAppear` re-fire.
    @State private var hasBootstrapped = false

    /// Which legacy-note prompt (if any) is currently being shown, and for
    /// which note. See `.claude/designs/multi-notes/design.md` ("Legacy Note
    /// Import Flow") for the full state machine this drives.
    enum LegacyPrompt: Identifiable {
        case importOffer(Note)
        case confirmDelete(Note)

        var id: UUID {
            switch self {
            case .importOffer(let note), .confirmDelete(let note):
                return note.id
            }
        }
    }
    @State private var legacyPrompt: LegacyPrompt?

    private var selectedNote: Note? {
        allNotes.first { $0.id == selectedNoteID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedNoteID: $selectedNoteID)
        } detail: {
            NoteEditorView(note: selectedNote, selectedNoteID: $selectedNoteID)
        }
        .onAppear {
            columnVisibility = sidebarVisible ? .all : .detailOnly

            guard !hasBootstrapped else { return }
            hasBootstrapped = true

            tagLegacyNoteIfNeeded(context: modelContext)
            pruneEmptyFolders(context: modelContext)
            ensureDefaultNoteExists(context: modelContext)

            // Fetch fresh from the context rather than relying on the
            // reactive @Query above, which may not have refreshed yet in the
            // same run-loop turn as the inserts just performed above.
            let freshNotes = (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
            if let storedID = UUID(uuidString: selectedNoteIDString),
               freshNotes.contains(where: { $0.id == storedID }) {
                selectedNoteID = storedID
            } else {
                let firstRootNote = freshNotes
                    .filter { $0.parentFolder == nil }
                    .sorted { $0.sortIndex < $1.sortIndex }
                    .first
                selectedNoteID = firstRootNote?.id
            }

            // The app is now otherwise fully bootstrapped and showing a note;
            // only now check whether a legacy note is pending a decision and,
            // if so, surface the appropriate prompt on top.
            checkForPendingLegacyNote()
        }
        .onChange(of: selectedNoteID) { _, newValue in
            selectedNoteIDString = newValue?.uuidString ?? ""
        }
        .onChange(of: columnVisibility) { _, newValue in
            sidebarVisible = (newValue != .detailOnly)
        }
        .alert(
            "Import your previous note?",
            isPresented: Binding(
                get: {
                    if case .importOffer = legacyPrompt { return true }
                    return false
                },
                set: { isPresented in
                    if !isPresented { legacyPrompt = nil }
                }
            )
        ) {
            Button("Not Now", role: .cancel) {
                legacyPrompt = nil
            }
            Button("Import") {
                if case .importOffer(let legacy) = legacyPrompt {
                    importLegacyNote(legacy)
                }
            }
        } message: {
            Text("QuickText found a note from your previous single-note setup. Would you like to import it as a new note?")
        }
        .alert(
            "Delete the original note?",
            isPresented: Binding(
                get: {
                    if case .confirmDelete = legacyPrompt { return true }
                    return false
                },
                set: { isPresented in
                    if !isPresented { legacyPrompt = nil }
                }
            )
        ) {
            Button("Keep Both", role: .cancel) {
                legacyPrompt = nil
            }
            Button("Delete", role: .destructive) {
                if case .confirmDelete(let legacy) = legacyPrompt {
                    performDeleteLegacyNote(legacy)
                }
                legacyPrompt = nil
            }
        } message: {
            Text("A copy of this note now exists elsewhere in your notes. Delete the original?")
        }
        .frame(minWidth: 300, minHeight: 200)
    }

    /// Checks for a note tagged `isLegacy` and, if found, sets `legacyPrompt`
    /// to the appropriate step of the import/delete flow: "Import?" if it
    /// hasn't been offered yet, or straight to "Delete the original?" if it
    /// has (a copy already exists from a prior "Import" answer). See
    /// `.claude/designs/multi-notes/design.md` ("Legacy Note Import Flow").
    private func checkForPendingLegacyNote() {
        let legacyNotes = (try? modelContext.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.isLegacy == true }
        ))) ?? []
        guard let legacy = legacyNotes.first else { return }

        legacyPrompt = legacy.hasOfferedImport ? .confirmDelete(legacy) : .importOffer(legacy)
    }

    /// "Import" action: creates a new root-level note containing a copy of
    /// the legacy note's content, marks the legacy note as having been
    /// offered (so future launches skip straight to the delete-original
    /// prompt instead of re-offering import and creating a duplicate copy
    /// every time), and immediately advances to the "Delete the original?"
    /// prompt for the same legacy note, without waiting for another launch.
    private func importLegacyNote(_ legacy: Note) {
        let rootNotes = (try? modelContext.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.parentFolder == nil }
        ))) ?? []
        let nextSortIndex = (rootNotes.map(\.sortIndex).max() ?? -1) + 1

        let copy = Note(content: legacy.content, parentFolder: nil, sortIndex: nextSortIndex)
        modelContext.insert(copy)
        legacy.hasOfferedImport = true

        legacyPrompt = .confirmDelete(legacy)
    }

    /// "Delete" action on the "Delete the original note?" prompt: if the
    /// legacy note was the currently-selected note, resolves a fallback
    /// selection first (same pattern used for post-delete fallback elsewhere
    /// in this file/the sidebar: pick the first remaining root note by
    /// `sortIndex`, creating a fresh default note via `ensureDefaultNoteExists`
    /// if none would remain), then deletes the legacy note.
    private func performDeleteLegacyNote(_ legacy: Note) {
        let wasSelected = (selectedNoteID == legacy.id)
        modelContext.delete(legacy)
        if wasSelected {
            ensureDefaultNoteExists(context: modelContext)
            let freshNotes = (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
            let firstRootNote = freshNotes
                .filter { $0.parentFolder == nil }
                .sorted { $0.sortIndex < $1.sortIndex }
                .first
            selectedNoteID = firstRootNote?.id
        }
    }
}
