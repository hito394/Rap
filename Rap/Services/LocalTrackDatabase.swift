import Foundation

/// Local offline database of Japanese rap / hip-hop tracks.
/// Used as a fallback when iTunes Japan doesn't have a track indexed.
/// Entries have no artwork/preview URLs — the suggestion UI shows a placeholder icon.
struct LocalTrackDatabase {

    // MARK: - Search

    /// Returns up to `limit` tracks whose title contains all `titleWords`
    /// and (when `artist` is provided) whose artist matches.
    static func search(title: String, artist: String = "", limit: Int = 6) -> [iTunesTrack] {
        let titleLower = title.lowercased()
        let artistLower = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let titleWords = titleLower
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let artistWords = artistLower
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let candidates = tracks.filter { track in
            let tName = track.trackName.lowercased()
            let aName = track.artistName.lowercased()

            // Title must contain all query words
            let titleMatch: Bool
            if titleWords.isEmpty {
                titleMatch = tName.contains(titleLower)
            } else {
                titleMatch = titleWords.allSatisfy { tName.contains($0) }
            }
            guard titleMatch else { return false }

            // Artist filter (optional)
            if !artistLower.isEmpty {
                return aName.contains(artistLower)
                    || artistWords.contains(where: { aName.contains($0) })
            }
            return true
        }

        return Array(candidates.prefix(limit))
    }

    // MARK: - Track list

    private static let tracks: [iTunesTrack] = build()

    private static func build() -> [iTunesTrack] {
        let raw: [(String, String, String)] = [
            // (trackName, artistName, albumName)

            // ── BAD HOP ──────────────────────────────────────────────────────
            ("Kawasaki Drift",        "BAD HOP", "BAD HOP HOUSE"),
            ("Bump",                  "BAD HOP", "BAD HOP HOUSE"),
            ("Stay",                  "BAD HOP", "BAD HOP HOUSE"),
            ("City of Music",         "BAD HOP", "BAD HOP HOUSE"),
            ("Mad Stacks",            "BAD HOP", "BAD HOP HOUSE"),
            ("Money Gang",            "BAD HOP", "BAD HOP HOUSE"),
            ("Guidance",              "BAD HOP", "BAD HOP HOUSE 2"),
            ("Gutta",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Neon Light",            "BAD HOP", "BAD HOP HOUSE 2"),
            ("Miserable",             "BAD HOP", "BAD HOP HOUSE 2"),
            ("Red Roses",             "BAD HOP", "BAD HOP HOUSE 2"),
            ("Paper",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Chase",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("4 Eva",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Make U Move",           "BAD HOP", "Grateful"),
            ("Tokyo Kissed Me",       "BAD HOP", "Grateful"),
            ("Love Story",            "BAD HOP", "Grateful"),
            ("Champion",              "BAD HOP", "Grateful"),
            ("Bounce",                "BAD HOP", "Grateful"),
            ("Itsuka",                "BAD HOP", "Grateful"),
            ("HOP BOYS",              "BAD HOP", "GOLD DISK"),
            ("GOLD DISK",             "BAD HOP", "GOLD DISK"),
            ("Hollow",                "BAD HOP", "GOLD DISK"),
            ("1111",                  "BAD HOP", "GOLD DISK"),
            ("Blow",                  "BAD HOP", "GOLD DISK"),
            ("Never Stop",            "BAD HOP", "GOLD DISK"),
            ("Forever",               "BAD HOP", "GOLD DISK"),
            ("T.P.O",                 "T-Pablow", "T.P.O"),
            ("Flo Rida",              "T-Pablow", "T.P.O"),
            ("YZERR",                 "YZERR", "YZERR"),
            ("ALONE",                 "YZERR", "ALONE"),

            // ── KOHH / Loota ─────────────────────────────────────────────────
            ("だいじょうぶ",            "KOHH", "Monochrome"),
            ("Monochrome",            "KOHH", "Monochrome"),
            ("Dirt Boys",             "KOHH", "Monochrome"),
            ("Yellow Tape",           "KOHH", "Monochrome"),
            ("美しい日本",             "KOHH", "美しい日本"),
            ("Moshi Moshi",           "KOHH", "美しい日本"),
            ("Nobody",                "KOHH", "Nobody"),
            ("Beautiful Word",        "KOHH", "Nobody"),
            ("時間",                   "KOHH", "Untitled"),
            ("Die Young",             "KOHH", "Die Young"),
            ("Jukai",                 "KOHH", "Jukai"),
            ("Dirt",                  "KOHH", "Dirt"),

            // ── Awich ─────────────────────────────────────────────────────────
            ("Bad Bitch 美学",         "Awich", "GIFT"),
            ("Naked",                 "Awich", "Queendom"),
            ("Gila",                  "Awich", "Queendom"),
            ("Equality",              "Awich", "Queendom"),
            ("Queendom",              "Awich", "Queendom"),
            ("New Era",               "Awich", "GIFT"),
            ("Stepper",               "Awich", "GIFT"),
            ("Tempest",               "Awich", "Queendom"),
            ("遺書",                   "Awich", "Queendom"),
            ("縛りたい",               "Awich", "GIFT"),
            ("Shook Ones Pt.II",      "Awich", "Shook Ones Pt.II"),

            // ── Creepy Nuts ───────────────────────────────────────────────────
            ("助演男優賞",             "Creepy Nuts", "Creepy Nuts"),
            ("のびしろ",               "Creepy Nuts", "よふかしのうた"),
            ("Bling-Bang-Bang-Born",  "Creepy Nuts", "Bling-Bang-Bang-Born"),
            ("板の上の魔物",           "Creepy Nuts", "Case"),
            ("かつて天才だった俺たちへ", "Creepy Nuts", "かつて天才だった俺たちへ"),
            ("合法的トビ方ノススメ",   "Creepy Nuts", "合法的トビ方ノススメ"),
            ("刹那",                   "Creepy Nuts", "Creepy Nuts"),
            ("余白",                   "Creepy Nuts", "余白"),
            ("阿婆擦れ",               "Creepy Nuts", "よふかしのうた"),
            ("サントラ",               "Creepy Nuts", "Creepy Nuts"),
            ("生業",                   "Creepy Nuts", "Case"),
            ("かわいいじゃねえか",     "Creepy Nuts", "かわいいじゃねえか"),

            // ── 舐達麻 ────────────────────────────────────────────────────────
            ("FLOATIN'",              "舐達麻", "PHILOSOPHIA"),
            ("GANJA CRUISIN'",        "舐達麻", "PHILOSOPHIA"),
            ("ユレル",                 "舐達麻", "PHILOSOPHIA"),
            ("感覚",                   "舐達麻", "PHILOSOPHIA"),
            ("YBAB",                   "舐達麻", "YBAB"),
            ("G Anthem",              "舐達麻", "PHILOSOPHIA"),
            ("HHH",                   "BES", "HHH"),
            ("在るべき姿",             "BES", "在るべき姿"),

            // ── 漢 a.k.a. GAMI ────────────────────────────────────────────────
            ("大人になれ",             "漢 a.k.a. GAMI", "孤独へのルート"),
            ("天気予報士",             "漢 a.k.a. GAMI", "孤独へのルート"),
            ("ストロング9",            "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("まだ生きていた",         "漢 a.k.a. GAMI", "孤独へのルート"),
            ("Stay Gold",             "漢 a.k.a. GAMI", "Stay Gold"),
            ("剥きだし",               "MSC", "剥きだし"),

            // ── 般若 ──────────────────────────────────────────────────────────
            ("一番病",                 "般若", "一番病"),
            ("超人",                   "般若", "超人"),
            ("証人",                   "般若", "証人"),
            ("疾走",                   "般若", "疾走"),
            ("ハスリングはやめらんねぇ", "般若", "ハスリングはやめらんねぇ"),
            ("Sick of It",            "般若", "Sick of It"),
            ("東京コンクリートジャングル", "般若", "超人"),

            // ── ZORN ──────────────────────────────────────────────────────────
            ("life",                  "ZORN", "LIFE"),
            ("HERO",                  "ZORN", "HERO"),
            ("稼業",                   "ZORN", "稼業"),
            ("MONEY BACK GUARANTEE", "ZORN", "LIFE"),
            ("25時",                  "ZORN", "LIFE"),
            ("NAN-NAN",               "ZORN", "HERO"),
            ("晴れの特異日",           "ZORN", "HERO"),
            ("大丈夫",                 "ZORN", "HERO"),

            // ── 唾奇 ──────────────────────────────────────────────────────────
            ("春の温度",               "唾奇", "春の温度"),
            ("Alright",               "唾奇", "Alright"),
            ("MEMO",                  "showgo", "MEMO"),
            ("花びら",                 "唾奇", "花びら"),
            ("あの子のこと",           "唾奇", "あの子のこと"),
            ("暁",                     "唾奇", "暁"),
            ("KATACHI",               "唾奇", "KATACHI"),

            // ── Daichi Yamamoto ───────────────────────────────────────────────
            ("Checkmate",             "Daichi Yamamoto", "Checkmate"),
            ("Across the Clouds",     "Daichi Yamamoto", "Across the Clouds"),
            ("Nobody Knows",          "Daichi Yamamoto", "Nobody Knows"),
            ("Gummy",                 "Daichi Yamamoto", "Gummy"),
            ("Hold",                  "Daichi Yamamoto", "Hold"),
            ("Interlude",             "Daichi Yamamoto", "Checkmate"),

            // ── PUNPEE ────────────────────────────────────────────────────────
            ("夜間飛行",               "PUNPEE", "Novel Life"),
            ("Someone's Someone",     "PUNPEE", "Novel Life"),
            ("Novel Life",            "PUNPEE", "Novel Life"),
            ("The Softest",           "PUNPEE", "Novel Life"),
            ("MODERN TIMES",          "PUNPEE", "MODERN TIMES"),
            ("Movie On Friday",       "PUNPEE", "MODERN TIMES"),

            // ── 仙人掌 ────────────────────────────────────────────────────────
            ("VOICE",                 "仙人掌", "VOICE"),
            ("DOOM",                  "仙人掌", "DOOM"),
            ("Dos Mil Cinco",         "仙人掌", "Dos Mil Cinco"),
            ("CALL",                  "仙人掌", "CALL"),
            ("HOOD",                  "仙人掌", "HOOD"),

            // ── Anarchy ───────────────────────────────────────────────────────
            ("The Chase",             "Anarchy", "The Chase"),
            ("Hustle",                "Anarchy", "Hustle"),
            ("Road",                  "Anarchy", "Road"),
            ("Street Life",           "Anarchy", "Street Life"),

            // ── AK-69 ─────────────────────────────────────────────────────────
            ("The Anthem",            "AK-69", "The Anthem"),
            ("Coming Soon",           "AK-69", "Coming Soon"),
            ("One",                   "AK-69", "One"),
            ("Runway of Life",        "AK-69", "Runway of Life"),
            ("Sunrise",               "AK-69", "Sunrise"),
            ("Rising Sun",            "AK-69", "Rising Sun"),

            // ── SEEDA ─────────────────────────────────────────────────────────
            ("HEAVEN",                "SEEDA", "HEAVEN"),
            ("BLUE",                  "SEEDA", "BLUE"),
            ("花と雨",                "SEEDA", "BLUE"),

            // ── 呂布カルマ ────────────────────────────────────────────────────
            ("ガチガチ",               "呂布カルマ", "呂布カルマ"),
            ("俺の話",                 "呂布カルマ", "俺の話"),
            ("言い訳",                 "呂布カルマ", "言い訳"),

            // ── DOTAMA ────────────────────────────────────────────────────────
            ("回文",                   "DOTAMA", "回文"),
            ("DOTAMAの野望",           "DOTAMA", "DOTAMAの野望"),

            // ── 晋平太 ────────────────────────────────────────────────────────
            ("人間失格",               "晋平太", "人間失格"),
            ("PROUD",                  "晋平太", "PROUD"),

            // ── BIM ───────────────────────────────────────────────────────────
            ("The Beam",              "BIM", "The Beam"),
            ("Gravy",                 "BIM", "Gravy"),
            ("Straight Outta",        "BIM", "Straight Outta"),

            // ── issugi ────────────────────────────────────────────────────────
            ("GEMZ",                  "issugi", "GEMZ"),
            ("Neon Sign Ambience",    "issugi", "Neon Sign Ambience"),
            ("Night Renderer",        "issugi", "Night Renderer"),

            // ── JJJ ───────────────────────────────────────────────────────────
            ("P.C.W",                 "JJJ", "P.C.W"),
            ("Mirrors",               "JJJ", "Mirrors"),
            ("HIKARI",                "JJJ", "HIKARI"),

            // ── OMSB ──────────────────────────────────────────────────────────
            ("Mr. Nobody",            "OMSB", "Mr. Nobody"),
            ("Think Good",            "OMSB", "Think Good"),
        ]

        return raw.map { (title, artist, album) in
            iTunesTrack(
                trackName: title,
                artistName: artist,
                artworkUrl100: nil,
                previewUrl: nil,
                collectionName: album
            )
        }
    }
}
