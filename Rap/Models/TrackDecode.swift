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
        EraTile(label: "Golden Age", years: "1986–1994", color: "#8B6914", icon: "crown.fill"),
        EraTile(label: "East vs West", years: "1992–1997", color: "#1a3a5c", icon: "bolt.fill"),
        EraTile(label: "Bling Era", years: "1997–2006", color: "#4a2060", icon: "diamond.fill"),
        EraTile(label: "Ringtone Rap", years: "2006–2012", color: "#1a4a2a", icon: "phone.fill"),
        EraTile(label: "Trap Era", years: "2012–2018", color: "#3a1a1a", icon: "waveform"),
        EraTile(label: "SoundCloud", years: "2015–2019", color: "#1a2a4a", icon: "cloud.fill"),
        EraTile(label: "Drill Wave", years: "2018–Now", color: "#0d1a0d", icon: "music.note"),
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
        PickupTrack(title: "HUMBLE.", artist: "Kendrick Lamar", emoji: "👑"),
        PickupTrack(title: "God's Plan", artist: "Drake", emoji: "🙏"),
        PickupTrack(title: "Lose Yourself", artist: "Eminem", emoji: "🎤"),
        PickupTrack(title: "New York State of Mind", artist: "Nas", emoji: "🗽"),
        PickupTrack(title: "C.R.E.A.M.", artist: "Wu-Tang Clan", emoji: "💵"),
        PickupTrack(title: "Gin and Juice", artist: "Snoop Dogg", emoji: "🥂"),
        PickupTrack(title: "Juicy", artist: "The Notorious B.I.G.", emoji: "💎"),
        PickupTrack(title: "99 Problems", artist: "JAY-Z", emoji: "🔥"),
        PickupTrack(title: "Alright", artist: "Kendrick Lamar", emoji: "✊"),
        PickupTrack(title: "Sicko Mode", artist: "Travis Scott", emoji: "🌙"),
    ]
}
