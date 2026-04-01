import Foundation

struct RhymePair: Codable, Identifiable {
    var id = UUID()
    let word1: String
    let word2: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case word1, word2, type
    }
}

struct LyricsAnalysis: Codable {
    let rhymeTypes: [String]
    let rhymePairs: [RhymePair]
    let flowScore: Int
    let flowComment: String
    let highlights: String
    let tips: String

    enum CodingKeys: String, CodingKey {
        case rhymeTypes = "rhyme_types"
        case rhymePairs = "rhyme_pairs"
        case flowScore = "flow_score"
        case flowComment = "flow_comment"
        case highlights
        case tips
    }

    static func parse(from json: String) -> LyricsAnalysis? {
        let cleaned = json
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LyricsAnalysis.self, from: data)
    }
}
