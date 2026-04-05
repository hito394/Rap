import Foundation

struct RhymePair: Codable, Identifiable {
    var id = UUID()
    let word1: String
    let word2: String
    let type: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case word1, word2, type, explanation
    }
}

struct SlangEntry: Codable, Identifiable {
    var id = UUID()
    let word: String
    let reading: String?
    let meaning: String
    let origin: String?
    let usageNote: String?
    let region: String?

    enum CodingKeys: String, CodingKey {
        case word, reading, meaning, origin
        case usageNote = "usage_note"
        case region
    }
}

struct DoubleEntendre: Codable, Identifiable {
    var id = UUID()
    let line: String
    let surface: String
    let real: String
    let technique: String?

    enum CodingKeys: String, CodingKey {
        case line, surface, real, technique
    }
}

struct CulturalReference: Codable, Identifiable {
    var id = UUID()
    let reference: String
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case reference, explanation
    }
}

struct LyricsAnalysis: Codable {
    let rhymeTypes: [String]
    let rhymePairs: [RhymePair]
    let flowScore: Int
    let flowComment: String
    let slangGlossary: [SlangEntry]
    let doubleEntendres: [DoubleEntendre]
    let culturalReferences: [CulturalReference]
    let highlights: String
    let tips: String
    let lyricsExcerpt: String?
    let artistBackground: String?
    let songContext: String?
    let keyBars: [KeyBar]?

    enum CodingKeys: String, CodingKey {
        case rhymeTypes = "rhyme_types"
        case rhymePairs = "rhyme_pairs"
        case flowScore = "flow_score"
        case flowComment = "flow_comment"
        case slangGlossary = "slang_glossary"
        case doubleEntendres = "double_entendres"
        case culturalReferences = "cultural_references"
        case highlights
        case tips
        case lyricsExcerpt = "lyrics_excerpt"
        case artistBackground = "artist_background"
        case songContext = "song_context"
        case keyBars = "key_bars"
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
