import Foundation
import SwiftData

// One-time, startup, and cleanup helpers for the multi-notes tree.
// See `.claude/designs/multi-notes/design.md` ("Legacy Note Import Flow"
// and "Auto-Deleting Empty Folders") for the rationale behind each function
// here. Deliberately top-level (not namespaced under a type) since other
// files (e.g. SidebarActions.swift) call `deleteIfEmpty` directly per the
// shared contract in design.md.

/// Runs at most once ever (UserDefaults-flag-gated). On the very first
/// launch of the build that introduces the notes tree, whatever note(s)
/// already exist at that moment (there's at most one, from the old
/// single-note version) are tagged `isLegacy = true`. Never runs again, so
/// notes created afterward are never mistaken for the legacy note.
///
/// This purely *identifies* the legacy note — it does not copy or delete
/// anything. The explicit, user-confirmed import/delete flow lives in
/// `ContentView.swift`, driven by the `isLegacy`/`hasOfferedImport` fields
/// this function sets.
func tagLegacyNoteIfNeeded(context: ModelContext) {
    guard !UserDefaults.standard.bool(forKey: "hasTaggedLegacyNote") else { return }
    let preexisting = (try? context.fetch(FetchDescriptor<Note>())) ?? []
    for note in preexisting {
        note.isLegacy = true
    }
    UserDefaults.standard.set(true, forKey: "hasTaggedLegacyNote")
}

/// If there are zero `Note`s in the store at all (e.g. a brand-new
/// install with nothing to migrate), creates one empty root note.
func ensureDefaultNoteExists(context: ModelContext) {
    let count = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
    guard count == 0 else { return }
    let defaultNote = Note(content: "", parentFolder: nil, sortIndex: 0)
    context.insert(defaultNote)
}

/// Deletes `folder` if it now has no notes and no subfolders, then
/// repeats for its former parent — so a chain of now-empty ancestors
/// collapses in one call. Call this with the *old* parent right after
/// any operation that removes a note/folder from it (delete, or
/// drag-out reparent).
func deleteIfEmpty(_ folder: Folder, context: ModelContext) {
    guard folder.notes.isEmpty, folder.subfolders.isEmpty else { return }
    let parent = folder.parent
    context.delete(folder)
    if let parent {
        deleteIfEmpty(parent, context: context)
    }
}

/// Startup sweep: removes any folder left over with zero notes and zero
/// subfolders (e.g. one the user created and quit without populating).
/// Repeats until stable so a chain of nested empty folders fully
/// collapses, not just the deepest one.
func pruneEmptyFolders(context: ModelContext) {
    var didDelete = true
    while didDelete {
        didDelete = false
        for folder in (try? context.fetch(FetchDescriptor<Folder>())) ?? [] {
            if folder.notes.isEmpty && folder.subfolders.isEmpty {
                context.delete(folder)
                didDelete = true
            }
        }
    }
}
