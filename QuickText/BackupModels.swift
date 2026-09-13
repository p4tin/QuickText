import Foundation
import SwiftData

// Codable mirror of the Note/Folder tree, used by Backup/Restore. Nesting
// (subfolders/notes arrays) encodes the folder structure directly — no ids
// or parent pointers needed, since the document *is* the tree.
//
// isLegacy/hasOfferedImport are deliberately not included: they're one-time
// migration bookkeeping on Note, not user-facing content, and are not
// expected to round-trip through a backup (see requirements.md).

struct BackupNote: Codable {
    var content: String
    var sortIndex: Int
}

struct BackupFolder: Codable {
    var name: String
    var sortIndex: Int
    var notes: [BackupNote]
    var subfolders: [BackupFolder]
}

struct BackupDocument: Codable {
    var formatVersion: Int
    var createdAt: Date
    var rootNotes: [BackupNote]
    var rootFolders: [BackupFolder]
}

private let currentBackupFormatVersion = 1

/// Snapshots the entire current tree (every root note/folder and their full
/// subtrees) into a `BackupDocument`, in `sortIndex` order at each level.
func buildBackupDocument(context: ModelContext) -> BackupDocument {
    let rootFolders = (try? context.fetch(
        FetchDescriptor<Folder>(predicate: #Predicate { $0.parent == nil })
    )) ?? []
    let rootNotes = (try? context.fetch(
        FetchDescriptor<Note>(predicate: #Predicate { $0.parentFolder == nil })
    )) ?? []

    return BackupDocument(
        formatVersion: currentBackupFormatVersion,
        createdAt: .now,
        rootNotes: rootNotes.sorted { $0.sortIndex < $1.sortIndex }.map(backupNote),
        rootFolders: rootFolders.sorted { $0.sortIndex < $1.sortIndex }.map(backupFolder)
    )
}

private func backupNote(_ note: Note) -> BackupNote {
    BackupNote(content: note.content, sortIndex: note.sortIndex)
}

private func backupFolder(_ folder: Folder) -> BackupFolder {
    BackupFolder(
        name: folder.name,
        sortIndex: folder.sortIndex,
        notes: folder.notes.sorted { $0.sortIndex < $1.sortIndex }.map(backupNote),
        subfolders: folder.subfolders.sorted { $0.sortIndex < $1.sortIndex }.map(backupFolder)
    )
}

/// Deletes every existing root `Folder`/`Note` (cascade handles their
/// subtrees) and recreates the entire tree from `document`. Uses direct
/// `context.delete`/model initializers rather than `SidebarActions`'
/// `deleteFolder`/`deleteNote`/`createFolder`/`createNote`, since those carry
/// single-item semantics (empty-parent cleanup, sort-index-append) this bulk
/// replace operation doesn't need.
func applyBackupDocument(_ document: BackupDocument, context: ModelContext) {
    let existingFolders = (try? context.fetch(
        FetchDescriptor<Folder>(predicate: #Predicate { $0.parent == nil })
    )) ?? []
    let existingNotes = (try? context.fetch(
        FetchDescriptor<Note>(predicate: #Predicate { $0.parentFolder == nil })
    )) ?? []
    for folder in existingFolders { context.delete(folder) }
    for note in existingNotes { context.delete(note) }

    for backupNote in document.rootNotes {
        context.insert(Note(content: backupNote.content, parentFolder: nil, sortIndex: backupNote.sortIndex))
    }
    for backupFolder in document.rootFolders {
        insertFolder(backupFolder, parent: nil, context: context)
    }
}

@discardableResult
private func insertFolder(_ backupFolder: BackupFolder, parent: Folder?, context: ModelContext) -> Folder {
    let folder = Folder(name: backupFolder.name, parent: parent, sortIndex: backupFolder.sortIndex)
    context.insert(folder)

    for backupNote in backupFolder.notes {
        context.insert(Note(content: backupNote.content, parentFolder: folder, sortIndex: backupNote.sortIndex))
    }
    for child in backupFolder.subfolders {
        insertFolder(child, parent: folder, context: context)
    }
    return folder
}
