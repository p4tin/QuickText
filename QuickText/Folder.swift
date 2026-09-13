import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = "New Folder"
    var sortIndex: Int = 0
    var isExpanded: Bool = true

    var parent: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var subfolders: [Folder] = []

    @Relationship(deleteRule: .cascade, inverse: \Note.parentFolder)
    var notes: [Note] = []

    init(name: String = "New Folder", parent: Folder? = nil, sortIndex: Int = 0) {
        self.name = name
        self.parent = parent
        self.sortIndex = sortIndex
    }
}
