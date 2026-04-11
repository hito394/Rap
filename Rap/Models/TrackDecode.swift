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
        // ── BAD HOP / 川崎 ──
        PickupTrack(title: "Kawasaki Drift", artist: "BAD HOP", emoji: "🏎️"),
        PickupTrack(title: "Timeless", artist: "BAD HOP", emoji: "⏳"),
        PickupTrack(title: "Light it Up", artist: "BAD HOP", emoji: "💡"),
        PickupTrack(title: "Dear Wavy", artist: "BAD HOP", emoji: "🌊"),
        PickupTrack(title: "PINK CHAMPAGNE", artist: "T-Pablow", emoji: "🥂"),
        PickupTrack(title: "One Day", artist: "T-Pablow", emoji: "🌅"),
        PickupTrack(title: "Thug Life", artist: "Yzerr", emoji: "🖤"),
        // ── KOHH / Loota ──
        PickupTrack(title: "貧乏ゆすり", artist: "KOHH", emoji: "🌸"),
        PickupTrack(title: "WASTED", artist: "KOHH", emoji: "💫"),
        PickupTrack(title: "Dirt Cheap", artist: "KOHH", emoji: "🖤"),
        PickupTrack(title: "Never Change", artist: "KOHH", emoji: "♾️"),
        PickupTrack(title: "Yellow Tape", artist: "KOHH", emoji: "📼"),
        PickupTrack(title: "BYE", artist: "Loota", emoji: "👋"),
        // ── Awich ──
        PickupTrack(title: "Bad Bitch 美学", artist: "Awich", emoji: "👑"),
        PickupTrack(title: "Gila", artist: "Awich", emoji: "🦎"),
        PickupTrack(title: "Naked", artist: "Awich", emoji: "🔥"),
        PickupTrack(title: "Queendom", artist: "Awich", emoji: "👸"),
        PickupTrack(title: "ARIGATO", artist: "Awich", emoji: "🙏"),
        // ── Creepy Nuts ──
        PickupTrack(title: "Bling-Bang-Bang-Born", artist: "Creepy Nuts", emoji: "💥"),
        PickupTrack(title: "のびしろ", artist: "Creepy Nuts", emoji: "📈"),
        PickupTrack(title: "助演男優賞", artist: "Creepy Nuts", emoji: "🎬"),
        PickupTrack(title: "よふかしのうた", artist: "Creepy Nuts", emoji: "🌙"),
        PickupTrack(title: "バレる！", artist: "Creepy Nuts", emoji: "😱"),
        // ── 舐達麻 ──
        PickupTrack(title: "Rasen", artist: "舐達麻", emoji: "🌀"),
        PickupTrack(title: "GODBREATH BUDDHACESS", artist: "舐達麻", emoji: "🌿"),
        PickupTrack(title: "LONG SMOKE", artist: "舐達麻", emoji: "💨"),
        PickupTrack(title: "ローリン", artist: "舐達麻", emoji: "🍃"),
        // ── 般若 ──
        PickupTrack(title: "一番病", artist: "般若", emoji: "🗡️"),
        PickupTrack(title: "超人", artist: "般若", emoji: "⚡"),
        PickupTrack(title: "代紋 BACK IN THE DAYS", artist: "般若", emoji: "🃏"),
        // ── ZORN ──
        PickupTrack(title: "稼業", artist: "ZORN", emoji: "💼"),
        PickupTrack(title: "LIFE", artist: "ZORN", emoji: "🏡"),
        PickupTrack(title: "HERO", artist: "ZORN", emoji: "🦸"),
        PickupTrack(title: "Dear Papa", artist: "ZORN", emoji: "👨‍👧"),
        // ── 仙人掌 ──
        PickupTrack(title: "生業", artist: "仙人掌", emoji: "🌿"),
        PickupTrack(title: "港区ブルース", artist: "仙人掌", emoji: "🌃"),
        PickupTrack(title: "BOY MEETS WORLD", artist: "仙人掌", emoji: "🌍"),
        // ── 唾奇 ──
        PickupTrack(title: "春の温度", artist: "唾奇 & showgo", emoji: "🌸"),
        PickupTrack(title: "Alright", artist: "唾奇 & showgo", emoji: "✌️"),
        PickupTrack(title: "MEMO", artist: "唾奇 & showgo", emoji: "📝"),
        // ── Daichi Yamamoto ──
        PickupTrack(title: "Alter Ego", artist: "Daichi Yamamoto", emoji: "🎭"),
        PickupTrack(title: "Checkmate", artist: "Daichi Yamamoto", emoji: "♟️"),
        PickupTrack(title: "Nobody Knows", artist: "Daichi Yamamoto", emoji: "🎵"),
        // ── PUNPEE ──
        PickupTrack(title: "夜間飛行", artist: "PUNPEE", emoji: "✈️"),
        PickupTrack(title: "Novel Life", artist: "PUNPEE", emoji: "📖"),
        PickupTrack(title: "Someone's Someone", artist: "PUNPEE", emoji: "💿"),
        // ── 漢 / MSC ──
        PickupTrack(title: "剥きだし", artist: "MSC", emoji: "🔪"),
        PickupTrack(title: "孤独へのルート", artist: "漢 a.k.a. GAMI", emoji: "🛣️"),
        // ── SEEDA / Anarchy / AK-69 ──
        PickupTrack(title: "HEAVEN", artist: "SEEDA", emoji: "🕊️"),
        PickupTrack(title: "ROYALSTREETZ", artist: "Anarchy", emoji: "👑"),
        PickupTrack(title: "夜明けのBLUES", artist: "AK-69", emoji: "🌅"),
        // ── RHYMESTER ──
        PickupTrack(title: "B-BOYイズム", artist: "RHYMESTER", emoji: "🎤"),
        PickupTrack(title: "待ってろ今から本気出す", artist: "RHYMESTER", emoji: "⚡"),
        PickupTrack(title: "ザ・グレート・アマチュアリズム", artist: "RHYMESTER", emoji: "🎲"),
        PickupTrack(title: "余計なお世話だ", artist: "RHYMESTER", emoji: "🖐️"),
        // ── ZEEBRA / King Giddra ──
        PickupTrack(title: "空からの力", artist: "King Giddra", emoji: "🐉"),
        PickupTrack(title: "今すぐ欲しい", artist: "ZEEBRA", emoji: "💎"),
        PickupTrack(title: "Street Life Forever", artist: "ZEEBRA", emoji: "🏙️"),
        // ── KREVA / KICK THE CAN CREW ──
        PickupTrack(title: "マルシェ", artist: "KICK THE CAN CREW", emoji: "🛒"),
        PickupTrack(title: "sayonara sayonara", artist: "KICK THE CAN CREW", emoji: "👋"),
        PickupTrack(title: "アグレッシ部", artist: "KREVA", emoji: "💪"),
        PickupTrack(title: "音色", artist: "KREVA", emoji: "🎵"),
        // ── THA BLUE HERB ──
        PickupTrack(title: "未来は俺等の手の中", artist: "THA BLUE HERB", emoji: "🔷"),
        PickupTrack(title: "STILLING STILL DOGGING", artist: "THA BLUE HERB", emoji: "🌨️"),
        // ── RIP SLYME ──
        PickupTrack(title: "楽園ベイベー", artist: "RIP SLYME", emoji: "🌴"),
        PickupTrack(title: "GALAXY", artist: "RIP SLYME", emoji: "🌌"),
        PickupTrack(title: "One", artist: "RIP SLYME", emoji: "☝️"),
        // ── スチャダラパー ──
        PickupTrack(title: "今夜はブギー・バック", artist: "スチャダラパー", emoji: "🎶"),
        PickupTrack(title: "サマージャム'95", artist: "スチャダラパー", emoji: "☀️"),
        // ── BUDDHA BRAND / NITRO ──
        PickupTrack(title: "人間発電所", artist: "BUDDHA BRAND", emoji: "⚡"),
        PickupTrack(title: "証言", artist: "LAMP EYE", emoji: "📜"),
        PickupTrack(title: "NITRO MICROPHONE UNDERGROUND", artist: "NITRO MICROPHONE UNDERGROUND", emoji: "🎤"),
        // ── OZROSAURUS / Dragon Ash ──
        PickupTrack(title: "AREA AREA", artist: "OZROSAURUS", emoji: "🏙️"),
        PickupTrack(title: "HAYABUSA", artist: "OZROSAURUS", emoji: "🦅"),
        PickupTrack(title: "ロデム", artist: "OZROSAURUS", emoji: "🤝"),
        PickupTrack(title: "Grateful Days", artist: "Dragon Ash", emoji: "🙏"),
        PickupTrack(title: "陽はまたのぼりくりかえす", artist: "Dragon Ash", emoji: "☀️"),
        // ── NORIKIYO ──
        PickupTrack(title: "喧嘩商売", artist: "NORIKIYO", emoji: "⚔️"),
        PickupTrack(title: "孤高", artist: "NORIKIYO", emoji: "🏔️"),
        // ── ネクストジェネレーション ──
        PickupTrack(title: "20, Stop it.", artist: "KID FRESINO", emoji: "🧠"),
        PickupTrack(title: "Àmè", artist: "KID FRESINO", emoji: "🌧️"),
        PickupTrack(title: "Sloppy Joe", artist: "BIM", emoji: "🎸"),
        PickupTrack(title: "Big Fish", artist: "STUTS & BIM", emoji: "🐟"),
        PickupTrack(title: "Eutopia", artist: "STUTS", emoji: "🎹"),
        PickupTrack(title: "Memories", artist: "STUTS feat. BIM", emoji: "🎺"),
        PickupTrack(title: "Dos City", artist: "Dos Monos", emoji: "🏙️"),
        PickupTrack(title: "angel", artist: "Tohji", emoji: "😇"),
        PickupTrack(title: "GOKU", artist: "Tohji", emoji: "🔱"),
        PickupTrack(title: "Cho Wavy De Gomenne", artist: "JP THE WAVY", emoji: "🌊"),
        // ── Shing02 ──
        PickupTrack(title: "Luv(sic) pt.3", artist: "Nujabes feat. Shing02", emoji: "🎵"),
        // ── 鎮座 / バトル ──
        PickupTrack(title: "ちっちゃな頃から", artist: "鎮座DOPENESS", emoji: "🎪"),
        PickupTrack(title: "最高の夏", artist: "サイプレス上野とロベルト吉野", emoji: "☀️"),
        // ── SALU / SKY-HI / 千葉雄喜 ──
        PickupTrack(title: "In My Arms", artist: "SALU", emoji: "🤗"),
        PickupTrack(title: "Marble", artist: "SKY-HI", emoji: "🏛️"),
        PickupTrack(title: "チーム友達", artist: "千葉雄喜", emoji: "👥"),
        // ── Chico Carlito / KEIJU / IO ──
        PickupTrack(title: "Creep on", artist: "Chico Carlito", emoji: "🌙"),
        PickupTrack(title: "I'm Still Wavy", artist: "FLA$HBACK$", emoji: "🌊"),
        PickupTrack(title: "DRIFT", artist: "IO", emoji: "🌀"),
        // ── Campanella / Sweet William ──
        PickupTrack(title: "SOUP", artist: "Campanella", emoji: "🍲"),
        PickupTrack(title: "名も無き感情", artist: "Sweet William", emoji: "💭"),
        // ── 呂布カルマ ──
        PickupTrack(title: "Poker Face", artist: "呂布カルマ", emoji: "🃏"),
        // ── SHINGO★西成 ──
        PickupTrack(title: "Aint No Sunshine", artist: "SHINGO★西成", emoji: "🌧️"),
    ]
}
