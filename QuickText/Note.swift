import Foundation
import SwiftData

@Model // This macro tells SwiftData to manage this class in the database [cite: 83]
class Note {
    var id: UUID = UUID()
    var content: String
    var lastModified: Date
    var sortIndex: Int = 0

    var parentFolder: Folder?

    /// True only for the single note that existed before the notes tree
    /// existed (identified at most once, ever — see `tagLegacyNoteIfNeeded`
    /// in `NotesMaintenance.swift`). Stays true until the note is deleted,
    /// however that happens; never set on any other note.
    var isLegacy: Bool = false

    /// True once an "Import" copy has been made from this legacy note, so a
    /// later launch knows to skip straight to "Delete the original?" instead
    /// of re-asking "Import?" (which would otherwise create a duplicate copy
    /// every launch). Meaningless/unused on a non-legacy note.
    var hasOfferedImport: Bool = false

    init(content: String = "", parentFolder: Folder? = nil, sortIndex: Int = 0) {
        self.content = content
        self.lastModified = Date.now
        self.parentFolder = parentFolder
        self.sortIndex = sortIndex
    }

    /// Sidebar title: text up to the first newline, or a placeholder when empty.
    var title: String {
        if let firstLine = content.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first,
           !firstLine.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(firstLine)
        }
        return "Untitled Note"
    }
}
