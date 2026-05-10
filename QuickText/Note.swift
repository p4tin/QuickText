import Foundation
import SwiftData

@Model // This macro tells SwiftData to manage this class in the database [cite: 83]
class Note {
    var content: String
    var lastModified: Date
    
    init(content: String = "") {
        self.content = content
        self.lastModified = Date.now
    }
}
