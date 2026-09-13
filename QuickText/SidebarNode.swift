import Foundation

/// Unifies `Folder` and `Note` into a single tree-node type so the sidebar
/// can render both with one `OutlineGroup`/`List` hierarchy.
enum SidebarNode: Identifiable, Hashable {
    case folder(Folder)
    case note(Note)

    var id: UUID {
        switch self {
        case .folder(let folder): folder.id
        case .note(let note): note.id
        }
    }

    /// `nil` for notes (leaves). For folders, the sorted subfolders followed
    /// by the sorted notes — a folder can be transiently empty (`[]`) in the
    /// moment between its last child being removed and the cleanup pass that
    /// deletes it (see `NotesMaintenance`).
    var children: [SidebarNode]? {
        guard case .folder(let folder) = self else { return nil }
        let subfolders = folder.subfolders
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(SidebarNode.folder)
        let notes = folder.notes
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(SidebarNode.note)
        return subfolders + notes
    }
}
