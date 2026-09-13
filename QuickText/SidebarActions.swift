import Foundation
import SwiftData

// MARK: - Sidebar Actions
//
// Pure logic helpers for creating, deleting, renaming, and reorganizing
// notes/folders in the sidebar tree. No SwiftUI/UI code lives here — see
// `SidebarView.swift` for the views that call into these.
//
// `deleteNote`/`deleteFolder`/`reparent` all rely on `deleteIfEmpty(_:context:)`
// (defined in `NotesMaintenance.swift`) to collapse any parent folder left
// empty by the operation, per the "Empty folders are not kept around"
// requirement.

/// Creates and inserts a new, empty `Note` as a child of `parent` (or the
/// root if `parent` is nil), sorted after its existing siblings.
@discardableResult
func createNote(in parent: Folder?, context: ModelContext) -> Note {
    let sortIndex = nextNoteSortIndex(in: parent, context: context)
    let note = Note(content: "", parentFolder: parent, sortIndex: sortIndex)
    context.insert(note)
    return note
}

/// Creates and inserts a new "New Folder" as a child of `parent` (or the
/// root if `parent` is nil), sorted after its existing siblings.
@discardableResult
func createFolder(in parent: Folder?, context: ModelContext) -> Folder {
    let sortIndex = nextFolderSortIndex(in: parent, context: context)
    let folder = Folder(name: "New Folder", parent: parent, sortIndex: sortIndex)
    context.insert(folder)
    return folder
}

/// Deletes `note`, then collapses its former parent folder if that
/// deletion left it empty (and so on up the tree).
func deleteNote(_ note: Note, context: ModelContext) {
    let parent = note.parentFolder
    context.delete(note)
    if let parent {
        deleteIfEmpty(parent, context: context)
    }
}

/// Deletes `folder` (cascade delete handles its entire subtree), then
/// collapses its former parent folder if that deletion left it empty
/// (and so on up the tree).
func deleteFolder(_ folder: Folder, context: ModelContext) {
    let parent = folder.parent
    context.delete(folder)
    if let parent {
        deleteIfEmpty(parent, context: context)
    }
}

/// Renames `folder` to `newName`, trimmed of surrounding whitespace. A
/// blank result (empty after trimming) is rejected — the folder keeps its
/// current name rather than being left nameless.
func renameFolder(_ folder: Folder, to newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    folder.name = trimmed
}

/// Reparents a dragged item — exactly one of `note`/`folder` should be
/// non-nil — into `newParent` (nil = root).
///
/// When moving a folder, guards against creating a cycle: `newParent`
/// itself, and every folder in `newParent`'s ancestor chain, is checked
/// against the dragged folder; if it appears anywhere in that chain the
/// move is rejected (no-op) and `false` is returned.
///
/// Deliberately does NOT call `deleteIfEmpty` on the old parent, unlike
/// `deleteNote`/`deleteFolder`. Drag-and-drop is interactive and easy to
/// mistarget (see incident notes in design.md), and `deleteIfEmpty`
/// cascades — auto-deleting a folder the instant a drag empties it took
/// real user data down with it when a drop landed somewhere unintended.
/// A folder left empty by a drag now just sits there (fixed up by
/// `pruneEmptyFolders` on the next launch instead), which is recoverable
/// — dragging something back in — where an instant auto-delete was not.
@discardableResult
func reparent(note: Note?, folder: Folder?, into newParent: Folder?, context: ModelContext) -> Bool {
    if let folder {
        guard !wouldCreateCycle(moving: folder, into: newParent) else { return false }

        let sortIndex = nextFolderSortIndex(in: newParent, context: context)
        folder.parent = newParent
        folder.sortIndex = sortIndex
        return true
    }

    if let note {
        let sortIndex = nextNoteSortIndex(in: newParent, context: context)
        note.parentFolder = newParent
        note.sortIndex = sortIndex
        return true
    }

    return false
}

// MARK: - Private helpers

/// True if moving `folder` into `newParent` would create a cycle — i.e.
/// `newParent` is `folder` itself, or `folder` appears anywhere in
/// `newParent`'s ancestor chain.
private func wouldCreateCycle(moving folder: Folder, into newParent: Folder?) -> Bool {
    if newParent === folder { return true }
    var ancestor = newParent?.parent
    while let current = ancestor {
        if current === folder { return true }
        ancestor = current.parent
    }
    return false
}

/// One past the current max `sortIndex` among `parent`'s note children
/// (or the root-level notes, if `parent` is nil) — i.e. "sorts last".
private func nextNoteSortIndex(in parent: Folder?, context: ModelContext) -> Int {
    let siblings: [Note]
    if let parent {
        siblings = parent.notes
    } else {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.parentFolder == nil })
        siblings = (try? context.fetch(descriptor)) ?? []
    }
    return (siblings.map(\.sortIndex).max() ?? -1) + 1
}

/// One past the current max `sortIndex` among `parent`'s subfolder
/// children (or the root-level folders, if `parent` is nil) — i.e.
/// "sorts last".
private func nextFolderSortIndex(in parent: Folder?, context: ModelContext) -> Int {
    let siblings: [Folder]
    if let parent {
        siblings = parent.subfolders
    } else {
        let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.parent == nil })
        siblings = (try? context.fetch(descriptor)) ?? []
    }
    return (siblings.map(\.sortIndex).max() ?? -1) + 1
}
