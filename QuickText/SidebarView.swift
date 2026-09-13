import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Drag & Drop payload

extension UTType {
    /// Custom type identifying a dragged sidebar item (note or folder)
    /// within QuickText's own sidebar drag & drop. This is a same-app,
    /// in-process transfer only (not meant to interop with other apps'
    /// pasteboard readers), so it just needs to be a well-formed, unique
    /// exported UTI for `Transferable`/`dropDestination` to key off.
    static var quickTextSidebarItem: UTType {
        UTType(exportedAs: "com.cp-soft.QuickText.sidebaritem")
    }
}

/// What's carried across a sidebar drag: which kind of item (`note`/
/// `folder`) and its stable `id`. The drop side re-fetches the actual
/// SwiftData model object by `id` rather than trying to transfer the model
/// itself.
struct SidebarDragPayload: Codable, Transferable {
    enum Kind: Codable {
        case note
        case folder
    }

    var kind: Kind
    var id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .quickTextSidebarItem)
    }
}

/// Performs a sidebar drop: for each dragged payload, re-fetches the actual
/// `Note`/`Folder` model object by `id` and reparents it into `newParent`
/// (`nil` = root level) via `reparent(note:folder:into:context:)` from
/// `SidebarActions.swift` — which owns the cycle guard (rejecting a folder
/// dropped into itself or one of its own descendants) and the empty-parent
/// cleanup.
///
/// Returns `true` if at least one payload was found and successfully
/// reparented, `false` otherwise (e.g. the item no longer exists, or the
/// move was rejected as a cycle) — matching what SwiftUI's
/// `dropDestination(for:action:)` expects to report whether the drop was
/// handled. There will typically be exactly one payload, since this app
/// doesn't support multi-select drag.
@discardableResult
private func performSidebarDrop(
    _ payloads: [SidebarDragPayload],
    into newParent: Folder?,
    context: ModelContext
) -> Bool {
    var didApplyAny = false
    for payload in payloads {
        let targetID = payload.id
        switch payload.kind {
        case .note:
            let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == targetID })
            if let note = (try? context.fetch(descriptor))?.first,
               reparent(note: note, folder: nil, into: newParent, context: context) {
                didApplyAny = true
            }
        case .folder:
            let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == targetID })
            if let folder = (try? context.fetch(descriptor))?.first,
               reparent(note: nil, folder: folder, into: newParent, context: context) {
                didApplyAny = true
            }
        }
    }
    return didApplyAny
}

/// Sidebar tree of notes and folders, with creation, rename, delete, and
/// drag & drop UI.
///
/// This is Wave 3 of the multi-notes feature. Task 7 added the "+" toolbar
/// menu for creating notes/folders and the "currently active folder"
/// tracking. Task 8 added inline rename for folders (double-click a
/// folder's name) and delete via context menu (note and folder rows), gated
/// by a confirmation dialog, with sensible selection fallback when the
/// deleted note (or the folder containing it) was the one open in the
/// editor. Task 9 (this file, current state) adds drag & drop reorganizing:
/// note and folder rows are draggable, folder rows and the sidebar's own
/// root/background area are valid drop destinations that reparent the
/// dragged item there.
struct SidebarView: View {
    @Query(filter: #Predicate<Folder> { $0.parent == nil }, sort: \Folder.sortIndex)
    private var rootFolders: [Folder]

    @Query(filter: #Predicate<Note> { $0.parentFolder == nil }, sort: \Note.sortIndex)
    private var rootNotes: [Note]

    /// The currently-selected note, owned by the containing `ContentView`
    /// (which mirrors it to `@AppStorage` for persistence across launches).
    @Binding var selectedNoteID: UUID?

    @Environment(\.modelContext) private var modelContext

    /// Drives the note-delete confirmation dialog; non-nil while that dialog
    /// is up, for the note pending deletion.
    @State private var noteToDelete: Note?

    /// Drives the folder-delete confirmation dialog; non-nil while that
    /// dialog is up, for the folder pending deletion.
    @State private var folderToDelete: Folder?

    private var rootNodes: [SidebarNode] {
        rootFolders.map(SidebarNode.folder) + rootNotes.map(SidebarNode.note)
    }

    var body: some View {
        List(selection: $selectedNoteID) {
            ForEach(rootNodes) { node in
                SidebarNodeRow(
                    node: node,
                    onDeleteNote: { noteToDelete = $0 },
                    onDeleteFolder: { folderToDelete = $0 }
                )
            }
        }
        .dropDestination(for: SidebarDragPayload.self) { payloads, _ in
            // Dropping on the list's own background (i.e. not on a specific
            // folder row) moves the dragged item(s) to the root level.
            performSidebarDrop(payloads, into: nil, context: modelContext)
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("New Note") {
                        createNewNote()
                    }
                    Button("New Folder") {
                        createFolder(in: nil, context: modelContext)
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Note or Folder")
            }
        }
        .confirmationDialog(
            "Delete Note?",
            isPresented: Binding(
                get: { noteToDelete != nil },
                set: { isPresented in if !isPresented { noteToDelete = nil } }
            ),
            presenting: noteToDelete
        ) { note in
            Button("Delete", role: .destructive) {
                performDeleteNote(note)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            folderToDelete.map(folderDeleteTitle) ?? "Delete Folder?",
            isPresented: Binding(
                get: { folderToDelete != nil },
                set: { isPresented in if !isPresented { folderToDelete = nil } }
            ),
            presenting: folderToDelete
        ) { folder in
            Button("Delete", role: .destructive) {
                performDeleteFolder(folder)
            }
            Button("Cancel", role: .cancel) {}
        } message: { folder in
            Text(folderDeleteMessage(folder))
        }
    }

    /// Creates a new root-level note and selects it for immediate editing.
    private func createNewNote() {
        let note = createNote(in: nil, context: modelContext)
        selectedNoteID = note.id
    }

    /// Deletes `note`. If it was the currently-open note, resolves a
    /// fallback selection afterward.
    private func performDeleteNote(_ note: Note) {
        let wasSelected = (selectedNoteID == note.id)
        deleteNote(note, context: modelContext)
        if wasSelected {
            resolveSelectionAfterDeletion()
        }
    }

    /// Deletes `folder` (and, via cascade, its entire subtree). If the
    /// currently-selected note was somewhere inside that subtree — detected
    /// by re-fetching all notes and checking whether the previously-selected
    /// id still exists anywhere — resolves a fallback selection afterward.
    private func performDeleteFolder(_ folder: Folder) {
        deleteFolder(folder, context: modelContext)

        guard let currentSelection = selectedNoteID else { return }
        // Fetch fresh from the context rather than relying on the reactive
        // @Query, which may not have refreshed yet in the same run-loop turn
        // as the delete just performed above (same reasoning as
        // ContentView's startup bootstrap).
        let freshNotes = (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
        if !freshNotes.contains(where: { $0.id == currentSelection }) {
            resolveSelectionAfterDeletion()
        }
    }

    /// Picks a fallback selection: the first remaining root-level note (by
    /// `sortIndex`). If no notes remain anywhere, first creates a new
    /// default root note (via `ensureDefaultNoteExists`) so the app is never
    /// left with zero notes and a nil selection, then selects that.
    private func resolveSelectionAfterDeletion() {
        ensureDefaultNoteExists(context: modelContext)
        let freshNotes = (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
        let firstRootNote = freshNotes
            .filter { $0.parentFolder == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
            .first
        selectedNoteID = firstRootNote?.id
    }

    private func folderDeleteTitle(_ folder: Folder) -> String {
        (folder.notes.isEmpty && folder.subfolders.isEmpty)
            ? "Delete Folder?"
            : "Delete Folder and Its Contents?"
    }

    private func folderDeleteMessage(_ folder: Folder) -> String {
        guard !(folder.notes.isEmpty && folder.subfolders.isEmpty) else {
            return "This cannot be undone."
        }
        let itemCount = folder.notes.count + folder.subfolders.count
        return "This folder contains \(itemCount) item(s). Deleting it will also delete everything inside. This cannot be undone."
    }
}

/// Renders a single tree node.
///
/// Note rows are plain, selectable list rows (`.tag`-ged with the note's
/// `id` so `List(selection:)` can track them), with a "Delete" context menu.
/// Folder rows are rendered by `FolderRow` (see below), as `DisclosureGroup`s
/// bound directly to `Folder.isExpanded`, so expand/collapse state
/// round-trips through SwiftData like any other model edit and persists
/// across restarts.
private struct SidebarNodeRow: View {
    let node: SidebarNode
    var onDeleteNote: (Note) -> Void
    var onDeleteFolder: (Folder) -> Void

    var body: some View {
        switch node {
        case .note(let note):
            Label(note.title, systemImage: "doc.text")
                .lineLimit(1)
                .truncationMode(.tail)
                .tag(note.id)
                .draggable(SidebarDragPayload(kind: .note, id: note.id))
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        onDeleteNote(note)
                    }
                }

        case .folder(let folder):
            FolderRow(
                folder: folder,
                node: node,
                onDeleteNote: onDeleteNote,
                onDeleteFolder: onDeleteFolder
            )
        }
    }
}

/// Renders a single folder row: a `DisclosureGroup` bound to
/// `Folder.isExpanded`, whose label doubles as an inline rename field.
///
/// Rename state (`isRenaming`/`editedName`) is local `@State`, which is why
/// this needed to become its own view struct rather than staying inlined in
/// `SidebarNodeRow`'s `case .folder` branch — SwiftUI `@State` needs a
/// distinct view identity to live on, one per folder row.
///
/// Because a folder row carries no `.tag`, `List(selection:)` never treats
/// it as selectable — clicking a folder only opens/closes its
/// `DisclosureGroup` and never changes `selectedNoteID`, per
/// requirements.md's sidebar navigation acceptance criteria. A double-click
/// enters rename mode.
///
/// Design note (see design.md's "Risks" item 1): `OutlineGroup`'s
/// collection-based initializer (`OutlineGroup(data, children:)`, used for a
/// multi-root tree like this one) has no `isExpanded:` parameter — that hook
/// only exists on `OutlineGroup`'s *single-root* initializer, which doesn't
/// fit a sidebar with multiple root-level folders/notes. Since there's no
/// clean way to drive `OutlineGroup`'s own per-row disclosure state from
/// `Folder.isExpanded` in the multi-root case, this uses a manual
/// `DisclosureGroup`-per-folder-row instead, which persists cleanly.
private struct FolderRow: View {
    let folder: Folder
    let node: SidebarNode
    var onDeleteNote: (Note) -> Void
    var onDeleteFolder: (Folder) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var isRenaming = false
    @State private var editedName = ""
    @FocusState private var isNameFieldFocused: Bool
    @State private var isDropTargeted = false

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { folder.isExpanded },
                set: { folder.isExpanded = $0 }
            )
        ) {
            ForEach(node.children ?? []) { child in
                SidebarNodeRow(
                    node: child,
                    onDeleteNote: onDeleteNote,
                    onDeleteFolder: onDeleteFolder
                )
            }
        } label: {
            if isRenaming {
                TextField("Folder Name", text: $editedName)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        commitRename()
                    }
                    .onAppear {
                        isNameFieldFocused = true
                    }
                    .onChange(of: isNameFieldFocused) { _, focused in
                        // Losing focus (e.g. clicking elsewhere) also commits
                        // the rename, matching Finder-style inline editing.
                        if !focused {
                            commitRename()
                        }
                    }
            } else {
                Label(folder.name, systemImage: "folder.fill")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Fill the full row width so the drop target (below)
                    // covers the whole row, not just the icon+text — a drop
                    // in the row's trailing empty space would otherwise fall
                    // through to the sidebar's root-level drop handler
                    // instead of landing on this folder.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        beginRename()
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDeleteFolder(folder)
                        }
                    }
                    .background(
                        isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear
                    )
                    .draggable(SidebarDragPayload(kind: .folder, id: folder.id))
                    .dropDestination(for: SidebarDragPayload.self) { payloads, _ in
                        // Dropping onto this folder row moves the dragged
                        // item(s) into this folder specifically. The cycle
                        // guard (folder dropped into itself or its own
                        // descendant) lives in `reparent`, via
                        // `performSidebarDrop`.
                        performSidebarDrop(payloads, into: folder, context: modelContext)
                    } isTargeted: { targeted in
                        isDropTargeted = targeted
                    }
            }
        }
    }

    private func beginRename() {
        editedName = folder.name
        isRenaming = true
    }

    private func commitRename() {
        guard isRenaming else { return }
        renameFolder(folder, to: editedName)
        isRenaming = false
    }
}
