import Foundation
import SwiftData

@Model
class HistoryItem {
    var id: UUID
    var type: String        // "lyrics" | "track" | "search"
    var query: String
    var resultJSON: String
    var createdAt: Date

    init(type: String, query: String, resultJSON: String) {
        self.id = UUID()
        self.type = type
        self.query = query
        self.resultJSON = resultJSON
        self.createdAt = Date()
    }

    var typeLabel: String {
        switch type {
        case "lyrics": return "解析"
        case "track": return "解説"
        case "search": return "検索"
        default: return type
        }
    }
}
