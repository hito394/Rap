import Foundation

// MARK: - Unified slang definition (used across all views)
struct SlangDefinition: Identifiable {
    let id = UUID()
    let word: String
    let reading: String?
    let meaning: String
    let origin: String?
    let usageNote: String?
    let region: String?
}

extension SlangEntry {
    func asDefinition() -> SlangDefinition {
        SlangDefinition(word: word, reading: reading, meaning: meaning,
                        origin: origin, usageNote: usageNote, region: region)
    }
}

extension TrackSlangEntry {
    func asDefinition() -> SlangDefinition {
        SlangDefinition(word: word, reading: nil, meaning: meaning,
                        origin: origin, usageNote: nil, region: region)
    }
}

extension SlangBreakdown {
    func asDefinition() -> SlangDefinition {
        SlangDefinition(word: word, reading: nil, meaning: meaning,
                        origin: origin, usageNote: nil, region: nil)
    }
}

// MARK: - Era tiles
struct EraTile: Identifiable {
    let id = UUID()
    let label: String
    let years: String
    let color: String
    let icon: String
}

extension EraTile {
    static let list: [EraTile] = [
        EraTile(label: "日本語ラップ黎明期", years: "1986–1995", color: "#1a3a5c", icon: "flag.fill"),
        EraTile(label: "BUDDHA BRAND時代", years: "1995–2003", color: "#8B6914", icon: "crown.fill"),
        EraTile(label: "アンダーグラウンド黄金期", years: "2003–2010", color: "#4a2060", icon: "music.note"),
        EraTile(label: "バトルMC台頭", years: "2010–2015", color: "#1a4a2a", icon: "bolt.fill"),
        EraTile(label: "トラップ上陸", years: "2015–2018", color: "#3a1a1a", icon: "waveform"),
        EraTile(label: "メインストリーム化", years: "2018–2022", color: "#1a2a4a", icon: "sparkles"),
        EraTile(label: "現在のシーン", years: "2022–Now", color: "#0d1a0d", icon: "flame.fill"),
    ]
}

// MARK: - SlangBreakdown

struct SlangBreakdown: Codable, Identifiable {
    var id = UUID()
    let word: String
    let meaning: String
    let origin: String?

    enum CodingKeys: String, CodingKey {
        case word, meaning, origin
    }
}

struct KeyBar: Codable, Identifiable {
    var id = UUID()
    let bar: String
    let explanation: String
    let slangBreakdown: [SlangBreakdown]?
    let subtext: String?

    enum CodingKeys: String, CodingKey {
        case bar, explanation
        case slangBreakdown = "slang_breakdown"
        case subtext
    }
}

struct SampleInfo: Codable, Identifiable {
    var id = UUID()
    let originalArtist: String
    let originalTrack: String
    let originalYear: String?
    let sampledElement: String
    let howUsed: String
    let clearanceNote: String?

    enum CodingKeys: String, CodingKey {
        case originalArtist = "original_artist"
        case originalTrack = "original_track"
        case originalYear = "original_year"
        case sampledElement = "sampled_element"
        case howUsed = "how_used"
        case clearanceNote = "clearance_note"
    }
}

struct TrackSlangEntry: Codable, Identifiable {
    var id = UUID()
    let word: String
    let meaning: String
    let origin: String?
    let region: String?

    enum CodingKeys: String, CodingKey {
        case word, meaning, origin, region
    }
}

struct TrackDecode: Codable {
    let background: String
    let eraContext: String
    let rhymeTechniques: [String]
    let keyBars: [KeyBar]
    let samples: [SampleInfo]
    let slangGlossary: [TrackSlangEntry]
    let influences: [String]
    let legacy: String

    enum CodingKeys: String, CodingKey {
        case background
        case eraContext = "era_context"
        case rhymeTechniques = "rhyme_techniques"
        case keyBars = "key_bars"
        case samples
        case slangGlossary = "slang_glossary"
        case influences
        case legacy
    }

    static func parse(from json: String) -> TrackDecode? {
        let cleaned = json
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TrackDecode.self, from: data)
    }
}

// MARK: - Pickup tracks
struct PickupTrack: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let emoji: String
}

extension PickupTrack {
    static let list: [PickupTrack] = [
        PickupTrack(title: "Bad Bitch 美学", artist: "Awich", emoji: "👑"),
        PickupTrack(title: "Kawasaki Drift", artist: "BAD HOP", emoji: "🏎️"),
        PickupTrack(title: "貧乏ゆすり", artist: "KOHH", emoji: "🌸"),
        PickupTrack(title: "Pick Up", artist: "Creepy Nuts", emoji: "🎤"),
        PickupTrack(title: "Rasen", artist: "舐達麻", emoji: "🌀"),
        PickupTrack(title: "Don't Trust Me", artist: "BAD HOP", emoji: "🔥"),
        PickupTrack(title: "PINK CHAMPAGNE", artist: "T-Pablow", emoji: "🥂"),
        PickupTrack(title: "WASTED", artist: "KOHH", emoji: "💫"),
        PickupTrack(title: "生業", artist: "仙人掌", emoji: "🌿"),
        PickupTrack(title: "Alter Ego", artist: "Daichi Yamamoto", emoji: "🎭"),
    ]
}
